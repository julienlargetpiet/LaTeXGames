#!/bin/bash

# --- FORCE REAL INPUT ---
exec 3</dev/tty

# --- RAW MODE ---
stty -icanon -echo
trap "stty sane" EXIT

# --- CONSTANTS ---
DINO_X_MIN=1
DINO_X_MAX=2

SAFE_START=15     # first cactus starts well to the right
MIN_GAP=5         # minimum gap between cacti
MAX_EXTRA_GAP=4   # random extra gap: 0..4

OFFSCREEN=-100    # inactive cactus parking spot

# --- INITIAL STATE ---
dinoy=0
jump_timer=0
gameover=0
score=0
time=0

num_cactus=1
cactus1x=$OFFSCREEN
cactus2x=$OFFSCREEN
cactus3x=$OFFSCREEN

spawn_wave() {
  num_cactus=$((RANDOM % 3 + 1))

  cactus1x=$SAFE_START
  cactus2x=$OFFSCREEN
  cactus3x=$OFFSCREEN

  if [ "$num_cactus" -gt 1 ]; then
    cactus2x=$((cactus1x + MIN_GAP + RANDOM % (MAX_EXTRA_GAP + 1)))
  fi

  if [ "$num_cactus" -gt 2 ]; then
    cactus3x=$((cactus2x + MIN_GAP + RANDOM % (MAX_EXTRA_GAP + 1)))
  fi
}

reset_game() {
  dinoy=0
  jump_timer=0
  gameover=0
  score=0
  time=0
  spawn_wave
}

build_fmt() {
  pdflatex -interaction=nonstopmode -ini -jobname=main "&pdflatex" mylatexformat.ltx """main.tex""" > /dev/null < /dev/null
}

move_cacti() {
  if [ "$num_cactus" -gt 0 ]; then
    cactus1x=$((cactus1x - 1))
  fi
  if [ "$num_cactus" -gt 1 ]; then
    cactus2x=$((cactus2x - 1))
  fi
  if [ "$num_cactus" -gt 2 ]; then
    cactus3x=$((cactus3x - 1))
  fi
}

all_cacti_gone() {
  if [ "$num_cactus" -gt 0 ] && [ "$cactus1x" -ge 0 ]; then return 1; fi
  if [ "$num_cactus" -gt 1 ] && [ "$cactus2x" -ge 0 ]; then return 1; fi
  if [ "$num_cactus" -gt 2 ] && [ "$cactus3x" -ge 0 ]; then return 1; fi
  return 0
}

update_jump() {
  if [ "$jump_timer" -gt 3 ]; then
    dinoy=2
  elif [ "$jump_timer" -gt 1 ]; then
    dinoy=1
  else
    dinoy=0
  fi

  if [ "$jump_timer" -gt 0 ]; then
    jump_timer=$((jump_timer - 1))
  fi
}

check_one_collision() {
  local cx=$1

  # cactus rectangle: [cx, cx+0.5]
  # dino rectangle:   [1, 2]
  # since x is integer here, overlap is well approximated by:
  # cactus left edge <= dino right edge
  # and cactus not fully left of dino
  if [ "$cx" -le "$DINO_X_MAX" ] && [ $((cx + 1)) -gt "$DINO_X_MIN" ] && [ "$dinoy" -lt 2 ]; then
    gameover=1
    echo "GAME OVER"
  fi
}

write_state() {
  cat > state.tex <<EOF
\def\dinoy{$dinoy}
\def\gameover{$gameover}
\def\score{$score}
\def\time{$time}
\def\numcactus{$num_cactus}
\def\cactusax{$cactus1x}
\def\cactusbx{$cactus2x}
\def\cactuscx{$cactus3x}
EOF
}

render_frame() {
  pdflatex -fmt=main.fmt -interaction=nonstopmode main.tex > /dev/null < /dev/null
}

# --- START GAME ---
reset_game
build_fmt

while true; do
  key=""
  read -u 3 -rsn1 -t 0.1 key

  case "$key" in
    j)
      if [ "$jump_timer" -eq 0 ] && [ "$gameover" -eq 0 ]; then
        echo "JUMP"
        jump_timer=6
      fi
      ;;
    r)
      echo "RELOAD"
      reset_game
      ;;
    q)
      echo "QUIT"
      exit 0
      ;;
  esac

  if [ "$gameover" -eq 0 ]; then
    move_cacti

    if all_cacti_gone; then
      spawn_wave
    fi

    update_jump

    if [ "$num_cactus" -gt 0 ]; then
      check_one_collision "$cactus1x"
    fi
    if [ "$num_cactus" -gt 1 ]; then
      check_one_collision "$cactus2x"
    fi
    if [ "$num_cactus" -gt 2 ]; then
      check_one_collision "$cactus3x"
    fi

    echo "$cactus1x , $cactus2x , $cactus3x"

    score=$((score + 1))
    time=$((score % 100))
  fi

  write_state
  render_frame
  sleep 0.1
done


