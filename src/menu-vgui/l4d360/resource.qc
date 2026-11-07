/* Xbox title resource adapter. Coordinates remain in Source's 480-line space.
 * Original .res files are loaded without rewriting their conditions or layouts.
 * This reader implements the KeyValues subset used by the supplied title files.
 */
#define L4D360_TITLE_MENU
var float autocvar_ui_l4d360 = 1;

class l4dResource
{
public:
    void l4dResource(void);
    nonvirtual bool Load(string path);
    nonvirtual string Get(string path, string fallback = "");
    nonvirtual float Number(string path, float fallback);
    nonvirtual void Put(string path, string value);
    nonvirtual void Release(void);
private:
    hashtable m_values;
    string m_source;
    string m_file;
    string m_token;
    int m_at;
    bool m_error;
    nonvirtual void Next(void);
    nonvirtual bool Condition(string expression);
    nonvirtual void ReadBlock(string prefix, bool enabled, int depth);
};

void l4dResource::l4dResource(void)
{
    m_values = hash_createtab(256, EV_STRING);
}

void l4dResource::Put(string path, string value)
{
    hash_add(m_values, strtolower(path), value, EV_STRING | HASH_REPLACE);
}

string l4dResource::Get(string path, string fallback = "")
{
    return (string)hash_get(m_values, strtolower(path), fallback, EV_STRING);
}

float l4dResource::Number(string path, float fallback)
{
    return stof(Get(path, ftos(fallback)));
}

void l4dResource::Release(void)
{
    hash_destroytab(m_values);
    remove(this);
}

void l4dResource::Next(void)
{
    int total = strlen(m_source);
    m_token = "";
    while (m_at < total) {
        int ch = str2chr(m_source, m_at);
        if (ch <= 32) { m_at++; continue; }
        if (substring(m_source, m_at, 2) == "//") {
            while (m_at < total && str2chr(m_source, m_at) != 10) m_at++;
            continue;
        }
        break;
    }
    if (m_at >= total) return;
    int start = m_at;
    string first = substring(m_source, m_at++, 1);
    if (first == "{" || first == "}") { m_token = first; return; }
    if (first == "\"") {
        while (m_at < total) {
            string character = substring(m_source, m_at++, 1);
            if (character == "\"") return;
            if (character == "\\" && m_at < total) {
                string escaped = substring(m_source, m_at, 1);
                if (escaped == "\"" || escaped == "\\") { character = escaped; m_at++; }
                else if (escaped == "n") { character = "\n"; m_at++; }
            }
            m_token = strcat(m_token, character);
        }
        m_error = true;
        return;
    }
    while (m_at < total) {
        int nextCharacter = str2chr(m_source, m_at);
        if (nextCharacter <= 32 || nextCharacter == 123 || nextCharacter == 125) break;
        m_at++;
    }
    m_token = substring(m_source, start, m_at - start);
}

bool l4dResource::Condition(string expression)
{
    string value = strtoupper(expression);
    if (value == "[$X360]") return true;
    if (value == "[$ENGLISH]") return true;
    if (value == "[$!WIN32]") return true;
    /* Other language branches do not apply to the imported English resources. */
    return false;
}

void l4dResource::ReadBlock(string prefix, bool enabled, int depth)
{
    if (depth > 16) { m_error = true; return; }
    Next();
    while (m_token != "}" && m_at <= strlen(m_source) && !m_error) {
        if (m_token == "") { m_error = true; return; }
        string key = m_token;
        Next();
        bool include = enabled;
        if (substring(m_token, 0, 1) == "[") {
            if (!Condition(m_token)) include = false;
            Next();
        }
        string path = strcat(prefix, key);
        if (m_token == "{") {
            if (include) Put(strcat(prefix, "@"), strcat(Get(strcat(prefix, "@")), key, ";"));
            ReadBlock(strcat(path, "/"), include, depth + 1);
            Next();
        } else {
            string value = m_token;
            Next();
            if (substring(m_token, 0, 1) == "[") {
                if (!Condition(m_token)) include = false;
                Next();
            }
            if (include) Put(path, value);
        }
    }
}

bool l4dResource::Load(string path)
{
    filestream stream = fopen(path, FILE_READ);
    if (stream < 0) { print(sprintf("L4D360: missing resource %s\n", path)); return false; }
    m_source = "";
    m_file = path;
    string line;
    while ((line = fgets(stream))) {
        m_source = strcat(m_source, line, "\n");
        if (strlen(m_source) > 524288) { m_error = true; break; }
    }
    fclose(stream);
    m_at = 0;
    Next(); /* resource name */
    Next();
    if (m_token != "{") m_error = true;
    if (!m_error) ReadBlock("", true, 0);
    m_source = "";
    if (m_error) print(sprintf("L4D360: malformed resource %s\n", path));
    return !m_error;
}

float L4D_Coord(string value, float extent)
{
    string first = substring(value, 0, 1);
    if (first == "r" || first == "f") return extent - stof(substring(value, 1, -1));
    if (first == "c") return extent * 0.5 + stof(substring(value, 1, -1));
    return stof(value);
}

string L4D_Leaf(string path)
{
    int last = -1;
    for (int i = 0; i < strlen(path); i++)
        if (substring(path, i, 1) == "/" || substring(path, i, 1) == "\\") last = i;
    return strtolower(substring(path, last + 1, -1));
}
