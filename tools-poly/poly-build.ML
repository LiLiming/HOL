val _ = PolyML.Compiler.prompt1:="";
val _ = PolyML.Compiler.prompt2:="";
val _ = PolyML.print_depth 0;
val _ = use "poly/poly-init.ML";
val _ = use "Holmake/Systeml.sig";
val _ = use "Holmake/Systeml.sml";
val _ = use "../tools/Holmake/Holmake_tools.sig"
val _ = use "../tools/Holmake/Holmake_tools.sml"
val _ = use "../tools/Holmake/internal_functions.sig"
val _ = use "../tools/Holmake/internal_functions.sml"
val _ = use "../tools/Holmake/Holmake_types.sig"
val _ = use "../tools/Holmake/Holmake_types.sml"
val _ = use "../tools/Holmake/ReadHMF.sig"
val _ = use "../tools/Holmake/ReadHMF.sml"
val _ = use "../tools/buildutils.sig";
val _ = use "../tools/buildutils.sml";
val _ = use "build.sml";
val _ = PolyML.shareCommonData build.main;
val _ = PolyML.export ("build", build.main);
