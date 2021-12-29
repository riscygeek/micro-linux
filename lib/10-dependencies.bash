#!/usr/bin/env bash

check_dependencies() {
   checkdep() {
      which "$1" &>/dev/null || fail "'$1' is not installed."
   }

   checkdep which
   checkdep gcc
   checkdep make

   # Check if sed accepts -i
   echo "Txst" > .testfile
   sed -i 's/x/e/' .testfile || fail "sed does not accept -i."
   rm -f .testfile
}
