source .env

for orig in `find . -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//');
  #envsubst < $orig > $target
  if ! grep -q DATA_E2E_BASE_URL $orig; then echo $orig; fi
  if ! grep -q tanzudatatap $target; then echo $target; fi
done
