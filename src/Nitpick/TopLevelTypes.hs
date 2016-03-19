{-# OPTIONS_GHC -Wall #-}
module Nitpick.TopLevelTypes (topLevelTypes) where

import Prelude hiding (maybe)
import qualified Data.Foldable as F
import qualified Data.Map as Map

import qualified AST.Expression.Valid as Valid
import qualified AST.Declaration as Decl
import qualified AST.Module.Name as ModuleName
import qualified AST.Pattern as P
import qualified AST.Type as Type
import qualified AST.Variable as Var
import qualified Elm.Package as Pkg
import qualified Reporting.Annotation as A
import qualified Reporting.Error.Type as Error
import qualified Reporting.Result as Result
import qualified Reporting.Warning as Warning


topLevelTypes
    :: Map.Map String Type.Canonical
    -> [Decl.ValidDecl]
    -> Result.Result Warning.Warning Error.Error ()
topLevelTypes typeEnv validDecls =
  do  F.traverse_ (warnMissingAnnotation typeEnv) validDecls
      checkMainType typeEnv validDecls


-- MISSING ANNOTATIONS

warnMissingAnnotation
    :: Map.Map String Type.Canonical
    -> Decl.ValidDecl
    -> Result.Result Warning.Warning Error.Error ()
warnMissingAnnotation typeEnv (A.A (region,_) decl) =
  case decl of
    Decl.Definition (Valid.Definition (A.A _ (P.Var name)) _ Nothing) ->
        case Map.lookup name typeEnv of
          Nothing ->
              return ()
          Just tipe ->
              Result.warn region (Warning.MissingTypeAnnotation name tipe)
    _ ->
        return ()


-- MAIN TYPE

checkMainType
    :: Map.Map String Type.Canonical
    -> [Decl.ValidDecl]
    -> Result.Result w Error.Error ()
checkMainType typeEnv decls =
    case decls of
      A.A (region,_) (Decl.Definition (Valid.Definition (A.A _ (P.Var "main")) _ _)) : _ ->
          case Map.lookup "main" typeEnv of
            Nothing ->
                return ()

            Just typeOfMain ->
                let tipe = Type.deepDealias typeOfMain
                in
                    if tipe `elem` validMainTypes
                      then return ()
                      else Result.throw region (Error.BadMain typeOfMain)

      _ : remainingDecls ->
          checkMainType typeEnv remainingDecls

      [] ->
          return ()


validMainTypes :: [Type.Canonical]
validMainTypes =
    [ element
    , html
    , nativeHtml
    , signal element
    , signal html
    , signal nativeHtml
    ]


html :: Type.Canonical
html =
    Type.Type (Var.fromModule virtualDom "Node")


virtualDom :: ModuleName.Canonical
virtualDom =
    ModuleName.Canonical (Pkg.Name "evancz" "virtual-dom") ["VirtualDom"]


nativeHtml :: Type.Canonical
nativeHtml =
    Type.Type (Var.fromModule nativeUi "NativeUi")


nativeUi :: ModuleName.Canonical
nativeUi =
    ModuleName.Canonical (Pkg.Name "elm-native-ui" "elm-native-ui") ["NativeUi"]


element :: Type.Canonical
element =
  core ["Graphics","Element"] "Element"


signal :: Type.Canonical -> Type.Canonical
signal tipe =
  Type.App (core ["Signal"] "Signal") [ tipe ]


core :: [String] -> String -> Type.Canonical
core home name =
  Type.Type (Var.inCore home name)
