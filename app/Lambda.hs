module Lambda where

type Lambda a = Var a | Expression a (Lambda a) | Application (Lambda a) (Lambda a)

instance Show a => Lambda a where
    show 
