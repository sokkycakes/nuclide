// Functional .res / KeyValues loader for BaseModUI
// Parses Source-engine "Resource/UI/<name>.res" KeyValues blocks into vgui widgets.
// Search order: Resource/UI/BaseModUI/<name>.res, then ui/l4d360ui/<lowercase>.res

filestream g_resFile;
string g_resLine;

string
Res_ReadLine(void)
{
	if (g_resFile < 0) return "";
	return fgets(g_resFile);
}

float
Res_ParseDim(string s, float fill)
{
	/* Source uses "f0" for "fill the parent"; treat any leading 'f' as fill mode */
	if (s == "" || s == "0") return 0;
	if (substring(s, 0, 1) == "f") return fill;
	return stof(s);
}

string
Res_StripLocPrefix(string s)
{
	/* Source localization keys start with '#'; we just drop it */
	if (substring(s, 0, 1) == "#") return substring(s, 1, -1);
	return s;
}

void
Res_BuildControl(CBaseModFrame parent, string ctrlClass, string ctrlName,
                 vector pos, vector size, string labelText, string image)
{
	if (ctrlClass == "") {
		return;
	}

	string lbl = Res_StripLocPrefix(labelText);

	/* The top-level Frame block describes the frame itself, not a child */
	if (ctrlClass == "Frame" || ctrlClass == "CBaseModFrame" ||
	    ctrlClass == "BaseModFrame") {
		if (size[0] > 0 && size[1] > 0) {
			parent.SetSize(size);
		}
		if (lbl != "") {
			parent.SetTitle(lbl);
		}
		return;
	}

	if (ctrlClass == "L4D360HybridButton" || ctrlClass == "CBaseModHybridButton" ||
	    ctrlClass == "Button" || ctrlClass == "CBaseLabelToggleButton") {
		vguiButton btn = spawn(vguiButton);
		btn.SetPos(pos);
		btn.SetSize(size);
		if (lbl != "") {
			btn.SetTitle(lbl);
		} else if (ctrlName != "") {
			btn.SetTitle(ctrlName);
		}
		parent.Add(btn);
		return;
	}

	if (ctrlClass == "Label" || ctrlClass == "CExLabel") {
		vguiLabel lab = spawn(vguiLabel);
		lab.SetPos(pos);
		lab.SetSize(size);
		if (lbl != "") {
			lab.SetTitle(lbl);
		}
		parent.Add(lab);
		return;
	}

	if (ctrlClass == "ImagePanel" || ctrlClass == "CrossfadableImage") {
		vguiPic pic = spawn(vguiPic);
		pic.SetPos(pos);
		pic.SetSize(size);
		if (image != "") {
			pic.SetImage(image);
		}
		parent.Add(pic);
		return;
	}

	/* fallback: generic widget so block is still visible while debugging */
	vguiWidget w = spawn(vguiWidget);
	w.SetPos(pos);
	w.SetSize(size);
	parent.Add(w);
}

void
Res_ParseFile(string resName, CBaseModFrame parent)
{
	string paths[2];
	paths[0] = sprintf("Resource/UI/BaseModUI/%s.res", resName);
	paths[1] = sprintf("ui/l4d360ui/%s.res", strtolower(resName));

	g_resFile = -1;
	int p;
	for (p = 0; p < 2; p++) {
		g_resFile = fopen(paths[p], FILE_READ);
		if (g_resFile >= 0) {
			print(sprintf("BaseModUI: loading %s\n", paths[p]));
			break;
		}
	}
	if (g_resFile < 0) {
		print(sprintf("BaseModUI: could not open %s.res in either location\n",
		              resName));
		return;
	}

	int depth = 0;
	string ctrlClass = "";
	string ctrlName = "";
	float xpos = 0;
	float ypos = 0;
	float wide = 64;
	float tall = 24;
	string labelText = "";
	string image = "";
	int controls = 0;

	vector psize = parent.GetSize();
	if (psize == [0, 0]) psize = [640, 480];

	while ((g_resLine = Res_ReadLine()) != "") {
		g_resLine = strtrim(g_resLine);
		if (g_resLine == "") continue;
		if (substring(g_resLine, 0, 2) == "//") continue;
		if (substring(g_resLine, 0, 1) == "/") continue;

		if (strstrofs(g_resLine, "{", 0) >= 0) {
			depth++;
			continue;
		}
		if (strstrofs(g_resLine, "}", 0) >= 0) {
			if (depth == 2) {
				Res_BuildControl(parent, ctrlClass, ctrlName,
				                 [xpos, ypos], [wide, tall],
				                 labelText, image);
				controls++;
				ctrlClass = "";
				ctrlName = "";
				xpos = 0;
				ypos = 0;
				wide = 64;
				tall = 24;
				labelText = "";
				image = "";
			}
			if (depth > 0) depth--;
			continue;
		}

		if (depth != 2) continue;

		/* Property line: "key"   "value" */
		float n = tokenizebyseparator(g_resLine, "\"");
		if (n < 4) continue;
		string k = argv(1);
		string v = argv(3);

		if (k == "ControlName") ctrlClass = v;
		else if (k == "fieldName") ctrlName = v;
		else if (k == "xpos") xpos = Res_ParseDim(v, psize[0]);
		else if (k == "ypos") ypos = Res_ParseDim(v, psize[1]);
		else if (k == "wide") wide = Res_ParseDim(v, psize[0]);
		else if (k == "tall") tall = Res_ParseDim(v, psize[1]);
		else if (k == "labelText") labelText = v;
		else if (k == "image") image = v;
	}

	fclose(g_resFile);
	g_resFile = -1;
	print(sprintf("BaseModUI: %s.res parsed, %d controls instantiated\n",
	              resName, controls));
}

void
BaseMod_LoadControlSettings(CBaseModFrame frame, string resName)
{
	if (resName == "") return;
	Res_ParseFile(resName, frame);
}
