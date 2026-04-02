#!/bin/bash

# --- INPUT SETUP ---
exec 3</dev/tty
stty -icanon -echo
trap "stty sane" EXIT

# --- STATE ---
step=0
scaleval=0.5
shoot=0
demon=0
gameover=0
lst="0,1,2"
score=0

# --- SCALE PER STEP ---
update_scale() {
  case $step in
    0) scaleval=0.5 ;;
    1) scaleval=0.9 ;;
    2) scaleval=1.4 ;;
  esac
}

# --- DEMON SPAWN ---
spawn_demon() {
  # 30% chance
  if (( RANDOM % 100 < 70 )); then
    demon=1
    echo "DEMON SPAWN"
  else
    demon=0
  fi
}

# --- RESET ---
reset_game() {
  step=0
  shoot=0
  demon=0
  gameover=0
  turndir=0
  lst="0,1,2"
  score=0
  update_scale
}

# --- WRITE STATE ---
write_state() {
cat > state.tex <<EOF
\def\step{$step}
\def\lst{$lst}
\def\scaleval{$scaleval}
\def\shoot{$shoot}
\def\demon{$demon}
\def\gameover{$gameover}
\def\score{$score}
\def\turndir{$turndir}
EOF
}

# --- RENDER ---
render() {
  pdflatex -interaction=nonstopmode main.tex > /dev/null < /dev/null
}

# --- INIT ---
reset_game
update_scale
write_state
render

while true; do

  update=0

  key=""
  read -u 3 -rsn1 -t 0.1 key

  # reset shoot each frame
  shoot=0

  turndir=0

  case "$key" in
    k) # forward
      if [ "$gameover" -eq 0 ]; then
        if [ "$step" -lt 2 ]; then
          step=$((step + 1))
          echo "FORWARD -> step=$step"

          if [ "$step" -eq 2 ]; then
            spawn_demon
          fi
        fi
      fi
      update=1
      ;;
    j) # backward
      if [ "$gameover" -eq 0 ]; then
        if [ "$step" -gt 0 ]; then

          # leaving step 2 -> check demon
          if [ "$step" -eq 2 ] && [ "$demon" -eq 1 ]; then
            echo "DEMON GOT YOU"
            gameover=1
          fi

          step=$((step - 1))
          echo "BACK -> step=$step"
        fi
      fi
      update=1
      ;;
    l) # right turn
      if [ "$step" -eq 2 ] && [ "$gameover" -eq 0 ]; then

        if [ "$demon" -eq 1 ]; then
          echo "TURNED WITH DEMON -> DEAD"
          gameover=1
        else
          echo "TURN RIGHT"
          turndir=2
          write_state
          render
          turndir=0
          sleep 0.3
          step=0
        fi
      fi
      update=1
      ;;
    h) # left turn
      if [ "$step" -eq 2 ] && [ "$gameover" -eq 0 ]; then

        if [ "$demon" -eq 1 ]; then
          echo "TURNED WITH DEMON -> DEAD"
          gameover=1
        else
          echo "TURN LEFT"
          turndir=1
          write_state
          render
          turndir=0
          sleep 0.5
          step=0
        fi
      fi
      update=1
      ;;
    s) # shoot
      if [ "$step" -eq 2 ] && [ "$demon" -eq 1 ]; then
        echo "DEMON KILLED"
        demon=0
        shoot=1
        score=$((score+1))
      fi
      update=1
      ;;
    r)
      echo "RESET"
      reset_game
      update=1
      ;;
    q)
      echo "QUIT"
      exit 0
      ;;
  esac

  if [[ "$step" -eq 0 ]]; then
    lst="0,1,2"
  fi
  if [[ "$step" -eq 1 ]]; then
    lst="0,1"
  fi
  if [[ "$step" -eq 2 ]]; then
    lst="0"
  fi

  if [[ "$update" -eq 1 ]]; then
    update_scale
    write_state
    render
    sleep 0.1
  fi

done


