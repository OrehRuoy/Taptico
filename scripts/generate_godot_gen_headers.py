#!/usr/bin/env python3
"""Generate the Godot *.gen.* headers needed to compile GodotPluginEntry.cpp
against engine headers, without running SCons.

Usage: python3 generate_godot_gen_headers.py /path/to/godot-4.6.3-stable

Calls the same generator functions Godot's SCsub files use, with minimal
stand-ins for SCons nodes. Only the files reachable from the bridge's include
graph (engine.h / class_db.h / object.h / ustring.h) are generated.
"""

import os
import sys


class _Node:
	"""Stand-in for a SCons node: str() is the path, read() the Value payload."""

	def __init__(self, value):
		self.value = value

	def __str__(self):
		return str(self.value)

	def read(self):
		return self.value


def main():
	if len(sys.argv) != 2:
		sys.exit(__doc__)
	godot_root = os.path.abspath(sys.argv[1])
	if not os.path.isfile(os.path.join(godot_root, "core", "config", "engine.h")):
		sys.exit(f"Not a Godot source tree: {godot_root}")

	# Generator modules use imports relative to the source root / their own dir.
	os.chdir(godot_root)
	sys.path.insert(0, godot_root)
	for sub in ("core", "core/extension", "core/object", "core/profiling"):
		sys.path.insert(0, os.path.join(godot_root, sub))

	import methods  # noqa: E402  (godot's methods.py)
	import core_builders  # noqa: E402
	import make_interface_header  # noqa: E402
	import make_wrappers  # noqa: E402
	import make_virtuals  # noqa: E402
	import profiling_builders  # noqa: E402

	def gen(rel_target, func, sources, env=None):
		out = os.path.join(godot_root, rel_target)
		os.makedirs(os.path.dirname(out), exist_ok=True)
		func([_Node(out)], sources, env if env is not None else {})
		print(f"generated {rel_target}")

	gen("core/disabled_classes.gen.h", core_builders.disabled_class_builder, [_Node([])])
	gen(
		"core/version_generated.gen.h",
		core_builders.version_info_builder,
		[_Node(methods.get_version_info("", silent=True))],
	)
	gen(
		"core/extension/gdextension_interface.gen.h",
		make_interface_header.run,
		[_Node(os.path.join(godot_root, "core", "extension", "gdextension_interface.json"))],
	)
	gen("core/extension/ext_wrappers.gen.inc", make_wrappers.run, [])
	gen("core/object/gdvirtual.gen.inc", make_virtuals.run, [])
	gen(
		"core/profiling/profiling.gen.h",
		profiling_builders.profiler_gen_builder,
		[],
		{"profiler": "", "profiler_sample_callstack": False, "profiler_track_memory": False},
	)


if __name__ == "__main__":
	main()
