module Classify (normalize) where

import Data.List
import Control.Monad
import Control.Arrow
import Control.Applicative ((<|>))
import Text.ParserCombinators.Parsec hiding ((<|>))
import Text.ParserCombinators.Parsec.Combinator
import Text.ParserCombinators.Parsec.Char
import Text.ParserCombinators.Parsec.Prim (parse)

data Edge = Dir Char | Inv Char deriving Eq

edgeLabel (Dir c) = c
edgeLabel (Inv c) = c

newtype Hole = Hole {
  edges :: [Edge]
} deriving Eq

instance Show Hole where
  show = concat . map showEdge . edges where
    showEdge (Dir c) = show c
    showEdge (Inv c) = [c, '\'']

newtype Sphere = Sphere {
  holes :: [Hole]
} deriving Eq

instance Show Sphere where
  show = unwords . map ((:) '(' . flip (++) ")" . show) . holes

invP = do c <- letter; _ <- char '\''; return c
edgeP = choice [fmap Inv invP, fmap Dir letter]
holeP = fmap Hole $ many1 edgeP
sphereP = fmap Sphere $ many1 $ between (char '(') (char ')') holeP
surfaceP = sepBy1 sphereP (char '+')
    
fromStr :: String -> Either String [Sphere]
fromStr s = left show $ parse surfaceP "" s
      
validate :: String -> Either String [Sphere]
validate = mfilter (\spheres' ->
                     let holes' = concat $ map holes spheres'
                         edges' = concat $ map edges holes'
                         labels' = sort $ map edgeLabel edges'
                         nub' = nub labels' in
                     nub' == (labels' \\ nub')) . fromStr
  
normalize :: String -> String
normalize s = case validate s of
  Left err -> error err
  Right spheres -> intercalate "+" (map show (zipSpheres spheres))  -- todo

findJust :: [Maybe a] -> (Maybe a)
findJust = foldl (<|>) Nothing

findTwin :: Edge -> [Sphere] -> Maybe (Edge, Hole, Sphere)
findTwin e =
  let l = edgeLabel e in
  findJust . (map (\s -> findTwin' l s (holes s))) where
    findTwin' l s = findJust . (map (\h -> findTwin'' l s h (edges h))) where
        findTwin'' l s h = fmap (\e -> (e, h, s)) . find ((==) l . edgeLabel)

flip' = reverse . (map inv) where
  inv (Dir u) = Inv u
  inv (Inv u) = Dir u

align (Dir _) (Dir _) es es' = es++(flip' es')
align (Inv _) (Inv _) es es' = es++(flip' es')
align _ _ es es' = es++es'

zipSpheres :: [Sphere] -> [Sphere]
zipSpheres = surfaces [] where
  surfaces acc [] = reverse acc
  surfaces acc (sphere:spheres) =
    let (surface, others) = zipOne (holes sphere) spheres in
    surfaces (surface:acc) others where
      zipOne holes' spheres =
        let doHoles [] doneHoles spheres = (Sphere $ reverse doneHoles, spheres)
            doHoles (h:tl) doneHoles spheres =
              let (hole, hs, ss) = doEdges (edges h) [] [] spheres in
              doHoles (hs++tl) (hole:doneHoles) ss where
                doEdges (e:tl) doneEdges newHoles spheres = case findTwin e spheres of
                  Nothing -> doEdges tl (e:doneEdges) newHoles spheres
                  Just (e', h', s') ->
                    let hs = (delete h' $ holes s')++newHoles
                        ss = delete s' spheres
                        aligned = align e e' tl $ delete e' (edges h') in
                    doEdges aligned doneEdges hs ss
                doEdges [] doneEdges newHoles spheres =
                  (Hole $ reverse doneEdges, newHoles, spheres)
        in doHoles holes' [] spheres
