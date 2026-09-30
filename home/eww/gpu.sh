# GPU load, temperature and VRAM from rocm-smi (modules/nixos/fans.nix), as
# {"ok": bool, "use": %, "temp": °C, "vram": %, "vram_text": "6.1/16.0 GiB",
#  "text": " 37%  52°C"} (padded to a fixed width for the bar).
# With several GPUs, the one with the most VRAM is shown.
json=$(rocm-smi --showuse --showtemp --showmeminfo vram --json 2>/dev/null) || true
# Without an amdgpu it prints nothing and still exits 0.
[ -n "$json" ] || json='{}'
jq -c '
  def pick(re): to_entries | map(select(.key | test(re))) | (.[0].value // null);
  def num: if . == null then null else (tonumber? // null) end;
  def gib: . / 1073741824 * 10 | round / 10;
  # Left-pad to n characters, so "  5%" and "100%" take the same room.
  def pad(n): tostring | ([range(n - length)] | map(" ") | join("")) + .;
  [to_entries[] | select(.key | startswith("card")) | .value
    | {use: (pick("^GPU use") | num),
       temp: ((pick("Temperature.*edge") // pick("^Temperature")) | num),
       total: (pick("VRAM Total Memory") | num),
       used: (pick("VRAM Total Used") | num)}]
  | (max_by(.total // 0) // null) as $g
  | if $g == null or $g.use == null then
      {ok: false, use: 0, temp: 0, vram: 0, vram_text: "", text: ""}
    else
      {ok: true, use: $g.use, temp: (($g.temp // 0) | round),
       vram: (if ($g.total // 0) > 0 then $g.used * 100 / $g.total | round else 0 end),
       vram_text: (if ($g.total // 0) > 0 then "\($g.used | gib)/\($g.total | gib) GiB" else "" end)}
      # Room for the worst case, "100% 200°C".
      | .text = "\(.use | pad(3))% \(.temp | pad(3))°C"
    end
' <<<"$json" 2>/dev/null || echo '{"ok":false,"use":0,"temp":0,"vram":0,"vram_text":"","text":""}'
