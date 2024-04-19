{-# LANGUAGE OverloadedStrings#-}

module Main where

import Control.Monad
import UnliftIO.Concurrent
import Data.Text
import qualified Data.Text.IO as TIO
import qualified Data.Text as T
import Discord.Internal.Types.Events
import System.Process
import Discord
import Discord.Types
import qualified Discord.Requests as R
import Discord.Handle (DiscordHandle(discordHandleLog))
import Data.Text.IO (hGetContents)
import GHC.IO.FD (openFile)
import GHC.IO.IOMode (IOMode(ReadMode))
import System.Environment (getArgs)
import Language.Haskell.Interpreter (eval, set, reset, setImportsQ, loadModules, liftIO,
                                     installedModulesInScope, languageExtensions, availableExtensions,
                                     typeOf, setTopLevelModules, runInterpreter,
                                     OptionVal(..), Interpreter,
                                     InterpreterError(..),GhcError(..),
                                     Extension(UnknownExtension))

readToken :: IO String
readToken = do
  args <- getArgs
  case Prelude.length args of
     1 -> return $ Prelude.head args
     _ -> putStrLn "You need to enter the bot token as a command line argument." >> return ""

startBot :: String -> IO ()
startBot tok = do
  err <- runDiscord $ def {
                          discordToken = "Bot " <> pack tok,
                          discordOnLog = \s -> TIO.putStrLn s >> TIO.putStrLn "",
                          discordOnEvent = eventHandler
                          }
  TIO.putStrLn err

fromBot :: Message -> Bool
fromBot = userIsBot . messageAuthor

checkText :: Message -> Text -> Bool
checkText m = (==) (toLower $ messageContent m)

replyMessage :: Message -> Text -> DiscordHandler ()
replyMessage oldMsg newMsg = void $ restCall (R.CreateMessage (messageChannelId oldMsg) newMsg)

haskellEvalHandler :: Message -> Text -> DiscordHandler ()
haskellEvalHandler msg content = do
  (_, out, err) <- liftIO $ readProcessWithExitCode "mueval" ["-n", "-l", "Def.hs", "-t", "10", "-e", unpack content] ""
  case (out, err) of
    ([], []) -> void $ restCall (R.CreateMessage (messageChannelId msg) "The process was terminated. Try the command again.")
    _ -> do
      case () of {_
        | Prelude.null out && Prelude.null err -> replyMessage msg "The process was terminated. Try again"
        | Prelude.null out -> replyMessage msg (pack err)
        | otherwise -> replyMessage msg  (pack ("```hs\n" <> out <> "```"))

      }
--messageCreateHandler msg = void $ restCall (R.CreateMessage (messageChannelId msg) (""))

haskellTypeHandler :: Message -> Text -> DiscordHandler ()
haskellTypeHandler msg content = do
  (_, out, err) <- liftIO $ readProcessWithExitCode "mueval" ["-n", "-l", "Def.hs", "-i", "-T", "-t", "10", "-e", unpack content] ""
  case (out, err) of
    ([], []) -> void $ restCall (R.CreateMessage (messageChannelId msg) "The process was terminated. Try the command again.")
    _ -> do
      case () of {_
        | Prelude.null out && Prelude.null err -> replyMessage msg "The process was terminated. Try again"
        | Prelude.null out -> replyMessage msg (pack err)
        | otherwise -> replyMessage msg  (pack ("```hs\n" <> out <> "```"))
      }

hoogleHandler :: Message -> Text -> DiscordHandler ()
hoogleHandler msg content = do
  (_, out, err) <- liftIO $ readProcessWithExitCode "hoogle" [unpack content] ""
  case (out, err) of
    ([], []) -> void $ restCall (R.CreateMessage (messageChannelId msg) "The process was terminated. Try the command again.")
    _ -> do
      case () of {_
        | Prelude.null out && Prelude.null err -> replyMessage msg "The process was terminated. Try again"
        | Prelude.null out -> replyMessage msg (pack err)
        | otherwise -> replyMessage msg (pack ("```" <> out <> "```"))
      }

helpHandler :: Message -> Text -> DiscordHandler ()
helpHandler msg _ = do
    void $ restCall (R.CreateMessageDetailed (messageChannelId msg) def {
                                                                    R.messageDetailedEmbeds = Just [def {
                                                                                                                        createEmbedTitle = "Lambdabot Reloaded",
                                                                                                                        createEmbedColor = Just DiscordColorPurple,
                                                                                                                        createEmbedDescription = "To run Haskell code: `>>= your code here`\n \
                                                                                                                        \To check a type: `:t type`\n \
                                                                                                                        \To look something up on Hoogle: `hoogle your search here`\n\
                                                                                                                        \To to get this help message: `>>=help`\
                                                                                                                        \"
                                                                                                                    }]
                                                                 })


commandPrefix :: Message -> CommandMapping () -> Maybe Text -- check if our command starts with the prefix, and if so, remove it
commandPrefix command (prefix,_) = do
  guard $ prefix `isPrefixOf` (toLower contents)
  return $ T.drop (T.length prefix) contents where contents = messageContent command

type CommandMapping f = (Text, Message -> Text -> DiscordHandler f)
type CommandList f = [CommandMapping f]
mappings :: CommandList ()
mappings = [(">>=help", helpHandler), (">>= ", haskellEvalHandler), (">>=", haskellEvalHandler), (":t ", haskellTypeHandler), ("hoogle ", hoogleHandler)]

executeCommand :: Message -> DiscordHandler () -- this is not really a safe function because i like to live dangerously, and absolutely terribly written too so probably that should be fixed
executeCommand msg = let findFirstMaybe pred (x:xs) = case pred x of {Nothing -> findFirstMaybe pred xs; Just y -> (y, x)}
                         (contents, command) = findFirstMaybe (commandPrefix msg) mappings in
                         snd command msg contents

eventHandler :: Event -> DiscordHandler ()
eventHandler event = case event of 
                     MessageCreate m -> unless (fromBot m) $ executeCommand m
                     _ -> return ()
                       
main :: IO ()
main = readToken >>= startBot
