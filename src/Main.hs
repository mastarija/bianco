{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import Language.Javascript.JSaddle.Null ( run )
import           Data.Aeson hiding (Object)
import           Data.Bool (bool)
import qualified Data.Map as M
import           GHC.Generics (Generic)

import           Miso (App(..), LogLevel(..), Effect)
import           Miso (focus, noEff, consoleLog, startApp, defaultEvents, (#>))
import           Miso.Html
import           Miso.Event.Types ( KeyCode(..) )
import           Miso.String (MisoString)
import qualified Miso.String as S

default (MisoString)

#if defined(wasm32_HOST_ARCH)
foreign export javascript "hs_start" main :: IO ()
#endif

data Model = Model
    { entries :: [Entry]
    , field :: MisoString
    , uid :: Int
    , visibility :: MisoString
    , step :: Bool
    }
    deriving (Show, Generic, Eq)

data Entry = Entry
    { description :: MisoString
    , completed :: Bool
    , editing :: Bool
    , eid :: Int
    , focussed :: Bool
    }
    deriving (Show, Generic, Eq)

instance ToJSON Entry
instance ToJSON Model

instance FromJSON Entry
instance FromJSON Model

emptyModel :: Model
emptyModel =
    Model
        { entries = []
        , visibility = "All"
        , field = mempty
        , uid = 0
        , step = False
        }

newEntry :: MisoString -> Int -> Entry
newEntry desc eid =
    Entry
        { description = desc
        , completed = False
        , editing = False
        , eid = eid
        , focussed = False
        }

data Msg
    = NoOp
    | CurrentTime Int
    | UpdateField MisoString
    | EditingEntry Int Bool
    | UpdateEntry Int MisoString
    | Add
    | Delete Int
    | DeleteComplete
    | Check Int Bool
    | CheckAll Bool
    | ChangeVisibility MisoString
    | FocusOnInput
    deriving (Show)

main :: IO ()
main = run $ startApp app

app :: App Model Msg
app = App emptyModel updateModel viewModel [] defaultEvents FocusOnInput Nothing Off

updateModel :: Msg -> Model -> Effect Msg Model
updateModel NoOp m = pure m
updateModel FocusOnInput m = (const NoOp <$> focus "input-box") #> m
updateModel (CurrentTime time) m = (const NoOp <$> ( consoleLog $ S.ms (show time) ) ) #> m
updateModel Add m = noEff m
                    { uid = uid m + 1
                    , field = mempty
                    , entries = entries m <> [newEntry ( field m ) ( uid m ) | not $ S.null $ field m ]
                    }
updateModel (UpdateField str) m = pure $ m { field = str }
updateModel (EditingEntry id' isEditing) m = pure $ m { entries =
          filterMap (entries m) (\t -> eid t == id') $ \t ->
            t { editing = isEditing
              , focussed = isEditing
              }
      }
updateModel (UpdateEntry id' task) m = pure $ m
    { entries = filterMap (entries m) ((== id') . eid) $ \t ->
        t { description = task }
    }
updateModel (Delete id') m = pure $ m
   { entries = filter (\t -> eid t /= id') (entries m)
   }
updateModel DeleteComplete m = pure $ m
    { entries = filter (not . completed) (entries m)
    }
updateModel (Check id' isCompleted) m = pure $ m
    { entries =
        filterMap (entries m) (\t -> eid t == id') $ \t ->
          t { completed = isCompleted }
    }
updateModel (CheckAll isCompleted) m = pure $ m
    { entries =
        filterMap (entries m) (const True) $ \t ->
          t { completed = isCompleted }
    }
updateModel (ChangeVisibility v) m = pure $ m { visibility = v }

filterMap :: [a] -> (a -> Bool) -> (a -> a) -> [a]
filterMap xs predicate f = go' xs
  where
    go' [] = []
    go' (y : ys)
        | predicate y = f y : go' ys
        | otherwise = y : go' ys

viewModel :: Model -> View Msg
viewModel m@Model{..} =
    div_
        [ class_ "todomvc-wrapper"
        ]
        [ section_
            [class_ "todoapp"]
            [ viewInput m field
            , viewEntries visibility entries
            , viewControls m visibility entries
            ]
        , infoFooter
        ]

viewEntries :: MisoString -> [Entry] -> View Msg
viewEntries visibility entries =
    section_
        [ class_ "main"
        , style_ $ M.singleton "visibility" cssVisibility
        ]
        [ input_
            [ class_ "toggle-all"
            , type_ "checkbox"
            , name_ "toggle"
            , id_ "toggle-all"
            , checked_ allCompleted
            , onClick $ CheckAll (not allCompleted)
            ]
        , label_
            [for_ "toggle-all"]
            [text $ S.pack "Mark all as complete"]
        , ul_ [class_ "todo-list"] $
            flip map (filter isVisible entries) $ \t ->
                viewKeyedEntry t
        ]
  where
    cssVisibility = bool "visible" "hidden" (null entries)
    allCompleted = all (== True) $ completed <$> entries
    isVisible Entry{..} =
        case visibility of
            "Completed" -> completed
            "Active" -> not completed
            _ -> True

viewKeyedEntry :: Entry -> View Msg
viewKeyedEntry = viewEntry

viewEntry :: Entry -> View Msg
viewEntry Entry{..} =
    liKeyed_
        (toKey eid)
        [ class_ $
            S.intercalate " " $
                ["completed" | completed] <> ["editing" | editing]
        ]
        [ div_
            [class_ "view"]
            [ input_
                [ class_ "toggle"
                , type_ "checkbox"
                , checked_ completed
                , onClick $ Check eid (not completed)
                ]
            , label_
                [onDoubleClick $ EditingEntry eid True]
                [text description]
            , button_
                [ class_ "destroy"
                , onClick $ Delete eid
                ]
                []
            ]
        , input_
            [ class_ "edit"
            , value_ description
            , name_ "title"
            , id_ $ "todo-" <> S.ms eid
            , onInput $ UpdateEntry eid
            , onBlur $ EditingEntry eid False
            , onEnter $ EditingEntry eid False
            ]
        ]

viewControls :: Model -> MisoString -> [Entry] -> View Msg
viewControls model visibility entries =
    footer_
        [ class_ "footer"
        , hidden_ (null entries)
        ]
        [ viewControlsCount entriesLeft
        , viewControlsFilters visibility
        , viewControlsClear model entriesCompleted
        ]
  where
    entriesCompleted = length . filter completed $ entries
    entriesLeft = length entries - entriesCompleted

viewControlsCount :: Int -> View Msg
viewControlsCount entriesLeft =
    span_
        [class_ "todo-count"]
        [ strong_ [] [text $ S.ms entriesLeft]
        , text (item_ <> " left")
        ]
  where
    item_ = S.pack $ bool " items" " item" (entriesLeft == 1)

viewControlsFilters :: MisoString -> View Msg
viewControlsFilters visibility =
    ul_
        [class_ "filters"]
        [ visibilitySwap "#/" "All" visibility
        , text " "
        , visibilitySwap "#/active" "Active" visibility
        , text " "
        , visibilitySwap "#/completed" "Completed" visibility
        ]

visibilitySwap :: MisoString -> MisoString -> MisoString -> View Msg
visibilitySwap uri visibility actualVisibility =
    li_
        []
        [ a_
            [ href_ uri
            , class_ $ S.concat ["selected" | visibility == actualVisibility]
            , onClick (ChangeVisibility visibility)
            ]
            [text visibility]
        ]

viewControlsClear :: Model -> Int -> View Msg
viewControlsClear _ entriesCompleted =
    button_
        [ class_ "clear-completed"
        , prop "hidden" (entriesCompleted == 0)
        , onClick DeleteComplete
        ]
        [text $ "Clear completed (" <> S.ms entriesCompleted <> ")"]

viewInput :: Model -> MisoString -> View Msg
viewInput _ task =
    header_
        [class_ "header"]
        [ h1_ [] [text "todos"]
        , input_
            [ class_ "new-todo"
            , id_ "input-box"
            , placeholder_ "What needs to be done?"
            , autofocus_ True
            , value_ task
            , name_ "newTodo"
            , onInput UpdateField
            , onEnter Add
            ]
        ]

onEnter :: Msg -> Attribute Msg
onEnter action =
    onKeyDown $ bool NoOp action . (== KeyCode 13)

infoFooter :: View Msg
infoFooter =
    footer_
        [class_ "info"]
        [ p_ [] [text "Double-click to edit a todo"]
        , p_
            []
            [ text "Written by "
            , a_ [href_ "https://github.com/dmjio"] [text "@dmjio"]
            ]
        , p_
            []
            [ text "Part of "
            , a_ [href_ "http://todomvc.com"] [text "TodoMVC"]
            ]
        ]
