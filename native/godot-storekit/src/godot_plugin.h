#ifndef GODOT_PLUGIN_H
#define GODOT_PLUGIN_H

#ifdef __cplusplus
extern "C" {
#endif

void register_godot_singleton(const char *name, void *instance);
void unregister_godot_singleton(const char *name);

#ifdef __cplusplus
}
#endif

#endif
