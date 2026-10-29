# Minion Chess – Features

A native macOS chess app where every piece is a goggle-wearing minion-style character.

## Pieces (original vector art)
| Piece | Costume |
|---|---|
| Pawn | Small one-eyed minion with a few hair strands |
| Knight | One-eyed minion in a plumed helmet |
| Bishop | Mitre hat with a cross |
| Rook | Stone tower hat |
| Queen | Crown, long hair, bow |
| King | Crown, beard, red cape |

White side is yellow with blue overalls. The dark side is purple by default; Grey and Green are available in Settings.

## Game modes
- Person vs. Computer, Computer vs. Person (board flips), Computer vs. Computer, Person vs. Person
- Variants:
  - **Normal** chess
  - **Crazyhouse** – captured pieces change sides and can be dropped back on the board (pockets shown next to the board)
  - **Losers** – captures are compulsory; lose all pieces except the king, or be checkmated/stalemated, to win
  - **Suicide** – captures are compulsory, the king is an ordinary piece; lose everything (or be stalemated) to win

## Rules implemented
Castling (both sides), en passant, promotion (with a picker), check / checkmate / stalemate detection, fifty-move rule,
threefold repetition, insufficient material, "Illegal Move!" feedback.

## Computer opponent
Built-in alpha-beta engine with iterative deepening, quiescence search and move ordering. 10 strength levels
(from ~0.1 s / 1 move ahead up to ~12 s / 14 moves ahead). Variant-aware evaluation.

## Playing aids
- **Hint** – blue arrow with the suggested move
- **Show Last Move** – orange arrow
- **Undo / Take Back** – removes your move and the computer's reply (⌘Z)
- **Resign** and **Offer Draw** (the computer accepts when it is not better)
- Legal-move dots, selected-square highlight, red glow on a king in check
- Click-to-move or drag-and-drop

## Game log and files
- Game log with numbered move list (SAN)
- Save / open games as **PGN** (⌘S / ⌘O), including Crazyhouse, Losers and Suicide variant tags

## Look and sound
- Board styles: Wood, Marble, Metal, Grass, Fur
- Edge notation (a–h, 1–8) toggle
- Spoken moves for computer and/or human moves

## Shortcuts
⌘N new game · ⌘O open · ⌘S save · ⌘Z take back · ⌘H hint · ⌘L last move · ⌘, settings

## Build
`./build_app.sh` produces `Minion Chess.app` (universal: Apple silicon + Intel). Rules self-test: `MinionChess --selftest`.
