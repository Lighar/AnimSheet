class_name GridDetectorUtils


static func get_median(lst: Array) -> float:
	if lst.is_empty(): return 0.0
	var s := lst.duplicate(); s.sort()
	var mid := s.size() / 2
	return (s[mid - 1] + s[mid]) / 2.0 if s.size() % 2 == 0 else float(s[mid])


static func get_prominence(arr: Array, peak_idx: int) -> float:
	var pv: float = arr[peak_idx]
	var lm := pv
	for j in range(peak_idx - 1, -1, -1):
		if arr[j] > pv: break
		if arr[j] < lm: lm = arr[j]
	var rm := pv
	for j in range(peak_idx + 1, arr.size()):
		if arr[j] > pv: break
		if arr[j] < rm: rm = arr[j]
	return pv - maxf(lm, rm)


static func get_base_spacing(projection: PackedInt32Array, label: String = "", min_size: int = 8) -> Variant:
	var n := projection.size()
	if n == 0: return null

	var mean_val := 0.0
	for v in projection: mean_val += v
	mean_val /= n

	var pc: Array = []
	for v in projection: pc.append(float(v) - mean_val)

	var autocorr: Array = []
	for lag in range(n):
		var s := 0.0
		for i in range(n - lag): s += pc[i] * pc[i + lag]
		autocorr.append(s)

	var max_val: float = autocorr.max()
	if max_val == 0.0:
		#print("GridDetectorUtils [%s]: autocorr flat." % label)
		return null

	var pt := max_val * 0.1
	var raw_peaks: Array = []
	var n_a := autocorr.size()
	var i := 1
	while i < n_a - 1:
		if autocorr[i] > autocorr[i - 1]:
			var ps := i
			while i < n_a - 1 and autocorr[i] == autocorr[ps]: i += 1
			if i < n_a and autocorr[ps] > autocorr[i]:
				raw_peaks.append((ps + i - 1) / 2)
			continue
		i += 1

	var prominent: Array = []
	for p in raw_peaks:
		if get_prominence(autocorr, p) >= pt: prominent.append(p)

	#print("GridDetectorUtils [%s]: raw=%d  prominent=%d" % [label, raw_peaks.size(), prominent.size()])

	prominent.sort_custom(func(a, b): return autocorr[a] > autocorr[b])
	var peaks: Array = []
	for p in prominent:
		var ok := true
		for fp in peaks:
			if abs(p - fp) < min_size: ok = false; break
		if ok: peaks.append(p)
	peaks.sort()

	#print("GridDetectorUtils [%s]: peaks = %s" % [label, str(peaks)])

	if not peaks.is_empty():
		var wz := [0] + peaks
		var diffs: Array = []
		for idx in range(1, wz.size()): diffs.append(wz[idx] - wz[idx - 1])
		return int(get_median(diffs))
	return null


static func optimize_grid(projection: PackedInt32Array, approx: Variant, total: int) -> Array:
	if approx == null: return [null, 0]
	var best_t: int = approx
	var best_off := 0
	var best_score := -INF
	var valid_ts: Array = []
	for d in range(2, total + 1):
		if total % d == 0 and abs(d - approx) <= approx * 0.5:
			valid_ts.append(d)
	if valid_ts.is_empty(): valid_ts = [approx]
	for t in valid_ts:
		var folded: Array = []; folded.resize(t); folded.fill(0)
		for idx in range(projection.size()): folded[idx % t] += projection[idx]
		var vd: float = folded.min()
		var vw := 0
		for val in folded:
			if val == vd: vw += 1
		var score := -vd * 1000.0 + vw - absf(t - approx) * 2.0
		if score > best_score:
			best_score = score
			best_t = t
			var found_offset = folded.find(vd)
			best_off = found_offset if found_offset >= 0 else 0  # Ensure non-negative
	return [best_t, best_off]


static func build_projections(img: Image) -> Array:
	## Returns [col_proj: PackedInt32Array, row_proj: PackedInt32Array]
	var img_width  := img.get_width()
	var img_height := img.get_height()
	var has_alpha  := img.detect_alpha() != Image.ALPHA_NONE

	var col_proj := PackedInt32Array(); col_proj.resize(img_width);  col_proj.fill(0)
	var row_proj := PackedInt32Array(); row_proj.resize(img_height); row_proj.fill(0)

	var total_active := 0
	for y in range(img_height):
		for x in range(img_width):
			var pixel  := img.get_pixel(x, y)
			var active := false
			if has_alpha:
				active = pixel.a > 0.0
			else:
				active = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) > (1.0 / 255.0)
			if active:
				row_proj[y] += 1
				col_proj[x] += 1
				total_active += 1

	#print("GridDetectorUtils: active=%d  col_max=%d  row_max=%d" % [total_active, packed_max(col_proj), packed_max(row_proj)])
	return [col_proj, row_proj]


static func detect(img: Image) -> Dictionary:
	## Main entry: returns { cell_width, cell_height, offset_x, offset_y }
	## or an empty Dictionary on failure.
	var img_width  := img.get_width()
	var img_height := img.get_height()

	var projs      := build_projections(img)
	var col_proj   : PackedInt32Array = projs[0]
	var row_proj   : PackedInt32Array = projs[1]

	var approx_w = get_base_spacing(col_proj, "col")
	var approx_h = get_base_spacing(row_proj, "row")
	#print("GridDetectorUtils: approx  w=%s  h=%s" % [str(approx_w), str(approx_h)])

	var result_w := optimize_grid(col_proj, approx_w, img_width)
	var result_h := optimize_grid(row_proj, approx_h, img_height)

	var cw = result_w[0]; var cx = result_w[1]
	var ch = result_h[0]; var cy = result_h[1]

	if cw == null and ch == null:
		return {}

	return {
		cell_width  = cw if cw != null else img_width,
		cell_height = ch if ch != null else img_height,
		offset_x    = cx if cw != null else 0,
		offset_y    = cy if ch != null else 0,
	}


static func packed_max(arr: PackedInt32Array) -> int:
	var m := 0
	for v in arr:
		if v > m: m = v
	return m
