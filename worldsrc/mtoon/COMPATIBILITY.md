# Local Godot 4.5 compatibility

The imported MToon 2.6.0 inspector declared helpers named `get_tooltip_text` and `emit_changed`. These collide with Godot 4.5 native Control/EditorProperty methods and prevent script compilation. They are renamed to `get_mtoon_tooltip_text` and `set_mtoon_property`, including every internal call. The existing direct material-assignment behavior is preserved.

Verified in Godot 4.5: plugin compilation, editor startup with MToon enabled, material recognition, shader parameter assignment, and the tooltip helper. This does not establish FTE rendering support: the Stiletto exporter still needs an explicit MToon material/shader adapter.

The accompanying VRM files were installed at `res://vrm` and MToon at `res://mtoon`. Hard-coded references to `res://addons/vrm` and `res://addons/mtoon` have been corrected to these installed locations.

The supplied VRM physics DLL reports that it was built for Godot 4.6. It cannot initialize in this project's Godot 4.5 editor. MToon's inspector does not depend on that DLL; VRM spring-bone simulation requires a compatible build or a separately planned editor upgrade. No binary or project-version substitution was made.
