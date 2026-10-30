/* Bulwark bot framework: the waypoint graph and A* routing in QC.
 * File format: docs/spec/bots.md, "Waypoint files". ISC licence. */

float bw_wp_loaded;	/* 1 loaded, -1 tried and failed */
float bw_wp_nlinks;
float *bw_as_g;
float *bw_as_f;
float *bw_as_parent;
float *bw_as_state;

float bw_wp_load(void)
{
	float fh, n, i, j, nl, total = 0, li;
	string line;
	float *counts;

	if (bw_wp_loaded)
		return (bw_wp_loaded > 0) ? TRUE : FALSE;
	bw_wp_loaded = -1;
	fh = fopen(strcat("data/", mapname, ".way"), FILE_READ);
	if (fh < 0) {
		bw_log(__NULL__, BWD_ERRORS | BWD_PATH, sprintf("no waypoints for %s", mapname));
		print(sprintf("bots: no waypoint file data/%s.way\n", mapname));
		return FALSE;
	}
	n = stof(fgets(fh));
	if (n <= 0) {
		fclose(fh);
		return FALSE;
	}
	/* links are counted on a first pass so they can live in one block */
	counts = memalloc(sizeof(float) * n);
	bw_wps = memalloc(sizeof(bw_wp_t) * n);
	for (i = 0; i < n; i++) {
		line = fgets(fh);
		tokenize(line);
		bw_wps[i].pos = [stof(argv(0)), stof(argv(1)), stof(argv(2))];
		bw_wps[i].radius = stof(argv(3));
		nl = stof(argv(4));
		counts[i] = nl;
		total += nl;
		for (j = 0; j < nl; j++)
			fgets(fh);
	}
	fclose(fh);

	bw_wplinks = memalloc(sizeof(bw_wplink_t) * max(1, total));
	fh = fopen(strcat("data/", mapname, ".way"), FILE_READ);
	fgets(fh);
	li = 0;
	for (i = 0; i < n; i++) {
		fgets(fh);
		bw_wps[i].firstlink = li;
		bw_wps[i].numlinks = counts[i];
		for (j = 0; j < counts[i]; j++) {
			tokenize(fgets(fh));
			bw_wplinks[li].to = stof(argv(0));
			bw_wplinks[li].cost = stof(argv(1));
			bw_wplinks[li].flags = stof(argv(2));
			if (bw_wplinks[li].to < 0 || bw_wplinks[li].to >= n)
				bw_wplinks[li].to = i;	/* bad link: points at itself */
			li++;
		}
	}
	fclose(fh);
	memfree(counts);

	bw_wp_count = n;
	bw_wp_nlinks = total;
	bw_as_g = memalloc(sizeof(float) * n);
	bw_as_f = memalloc(sizeof(float) * n);
	bw_as_parent = memalloc(sizeof(float) * n);
	bw_as_state = memalloc(sizeof(float) * n);
	bw_route_nodes = memalloc(sizeof(float) * n);
	bw_wp_loaded = 1;
	print(sprintf("bots: %g waypoints, %g links from data/%s.way\n", n, total, mapname));
	return TRUE;
}

/* the waypoint nearest pos (height counting three times); with los, the
 * nearest of the closest few that can be seen from pos, falling back to the
 * nearest */
float bw_wp_nearest(vector pos, float los)
{
	float i, k, best, bd, d, first = -1;
	vector wp;
	float tried[8];
	float ntried = 0;
	if (!bw_wp_load())
		return -1;
	for (k = 0; k < (los ? 8 : 1); k++) {
		best = -1;
		bd = 999999999;
		for (i = 0; i < bw_wp_count; i++) {
			float skip = FALSE, t;
			for (t = 0; t < ntried; t++)
				if (tried[t] == i)
					skip = TRUE;
			if (skip)
				continue;
			/* height counts extra: a waypoint on the floor below or above
			 * is further to walk than it looks */
			wp = bw_wps[i].pos;
			d = vlen(wp - pos) + fabs(wp_z - pos_z) * 2;
			if (d < bd) {
				bd = d;
				best = i;
			}
		}
		if (best < 0)
			break;
		if (first < 0)
			first = best;
		if (!los)
			return best;
		traceline(pos, bw_wps[best].pos, MOVE_NOMONSTERS, world);
		if (trace_fraction == 1)
			return best;
		tried[ntried++] = best;
	}
	return first;
}

/* A* from waypoint to waypoint, skipping links with forbidden flags.
 * Fills bw_route_nodes (start first) and bw_route_len. If the goal can't be
 * reached the route ends at the reached waypoint closest to it, and
 * bw_route_partial is set. */
float bw_route(float from, float to, float forbid)
{
	float i, cur, bf, l, nb, g, closest, cd, d, n;
	vector goal;

	bw_route_len = 0;
	bw_route_partial = FALSE;
	if (from < 0 || to < 0 || !bw_wp_load())
		return FALSE;
	n = bw_wp_count;
	goal = bw_wps[to].pos;
	for (i = 0; i < n; i++) {
		bw_as_state[i] = 0;
		bw_as_parent[i] = -1;
	}
	bw_as_g[from] = 0;
	bw_as_f[from] = vlen(bw_wps[from].pos - goal);
	bw_as_state[from] = 1;
	closest = from;
	cd = bw_as_f[from];

	while (1) {
		/* the open node with the lowest estimate (graphs are small) */
		cur = -1;
		bf = 999999999999;
		for (i = 0; i < n; i++)
			if (bw_as_state[i] == 1 && bw_as_f[i] < bf) {
				bf = bw_as_f[i];
				cur = i;
			}
		if (cur < 0)
			break;
		if (cur == to)
			break;
		bw_as_state[cur] = 2;
		d = vlen(bw_wps[cur].pos - goal);
		if (d < cd) {
			cd = d;
			closest = cur;
		}
		for (l = bw_wps[cur].firstlink; l < bw_wps[cur].firstlink + bw_wps[cur].numlinks; l++) {
			if (bw_wplinks[l].flags & forbid)
				continue;
			nb = bw_wplinks[l].to;
			if (bw_as_state[nb] == 2)
				continue;
			g = bw_as_g[cur] + max(1, bw_wplinks[l].cost);
			if (bw_as_state[nb] == 1 && g >= bw_as_g[nb])
				continue;
			bw_as_g[nb] = g;
			bw_as_f[nb] = g + vlen(bw_wps[nb].pos - goal);
			bw_as_parent[nb] = cur;
			bw_as_state[nb] = 1;
		}
	}

	if (bw_as_state[to] == 0 || (bw_as_state[to] == 1 && cur != to)) {
		bw_route_partial = TRUE;
		to = closest;
	}
	/* walk back from the end, then reverse */
	for (i = to; i >= 0 && bw_route_len < n; i = bw_as_parent[i])
		bw_route_nodes[bw_route_len++] = i;
	for (i = 0; i < bw_route_len / 2; i++) {
		l = bw_route_nodes[i];
		bw_route_nodes[i] = bw_route_nodes[bw_route_len - 1 - i];
		bw_route_nodes[bw_route_len - 1 - i] = l;
	}
	return TRUE;
}
