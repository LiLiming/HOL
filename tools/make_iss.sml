(* program to output iss file *)
structure make_iss = struct

structure FileSys = OS.FileSys

val holdir = Globals.HOLDIR
val systeml = Systeml.winnt_systeml

val sysname = Globals.release ^ " " ^ Int.toString Globals.version
val _ = print "Changing to hol directory\n"
val _ = FileSys.chDir holdir

fun die s = (print s; Process.exit Process.failure)

local
  open FileSys
  val _ = print "Purging source directory\n"
  fun traverse dir = let
    val dir0 = getDir ()
    val _ = chDir dir
    val ds = openDir "."
    fun dodir docfound acc =
      case readDir ds of
        NONE => (docfound, acc)
      | SOME s =>
          if isDir s then dodir docfound (s::acc)
          else
            if String.size s < 6 orelse
              String.extract(s, String.size s - 5, NONE) <> ".adoc"
            then
                (remove s; dodir docfound acc)
            else
              dodir true acc
    val (docfound, subdirectories) = dodir false []
    val _ = closeDir ds
    val subfound = foldl (fn (d,b) => traverse d orelse b) false subdirectories
    val _ = chDir dir0
  in
    if not docfound andalso not subfound then (rmDir dir; false) else true
  end
in
  val _ = traverse "src" handle OS.SysErr(s,_) => die ("OS error: "^s)
end

val _ = print "Compiling win-config.exe"
val _ = FileSys.chDir "tools"
val _ = if systeml ["mosmlc", "-I", "Holmake", "-o", "win-config.exe",
                    "win-config.sml"] = Process.success then ()
        else (print "Compilation failed!\n"; Process.exit Process.failure)
val _ = FileSys.chDir holdir


val header = "\
\[Setup]\n\
\AppName            = hol98\n\
\AppVerName         = hol98 - "^sysname^"\n\
\AppVersion         = "^sysname^"\n\
\DefaultDirName     = {pf}\\Hol\n\
\DefaultGroupName   = HOL\n\
\CompressLevel      = 9\n";

fun mem s [] = false | mem s (h::t) = s = h orelse mem s t

fun traverse worklist acc excludes =
  case worklist of
    [] => acc
  | (dir::rest) => let
      open FileSys
      val ds = openDir dir
      fun alldirs filefound worklist =
        case readDir ds of
          NONE => (filefound, worklist)
        | SOME f0 => let
            val f = Path.concat(dir, f0)
          in
            if isDir f then
              if not (mem f0 excludes) then
                alldirs filefound (f::worklist)
              else
                alldirs filefound worklist
            else alldirs true worklist
          end
      val (filefound, newworklist) = alldirs false rest
      val _ = closeDir ds
    in
      traverse newworklist ((dir,filefound)::acc) excludes
    end handle OS.SysErr(s,_) => die ("OS error: "^s)

fun initial_directories excludes = let
  open FileSys
  val ds = openDir "."
  fun readf filefound acc =
    case readDir ds of
      NONE => (filefound, acc)
    | SOME f =>
        if isDir f then
          if not (mem f excludes) then
            readf filefound (f::acc)
          else
            readf filefound acc
        else readf true acc
  val (filefound, result) = readf false []
  val _ = closeDir ds
in
  (filefound, List.rev result)
end handle OS.SysErr(s,_) => die ("OS error: "^s)

fun alldirs excludes = let
  val (filefound, ids) = initial_directories excludes
in
  (filefound, List.rev (traverse ids [] excludes))
end handle OS.SysErr(s,_) => die ("OS error: "^s)

fun trans #"/" = "\\" | trans x = str x
fun dir_string dirname = String.concat ["Name: \"{app}\\",
                                        String.translate trans dirname,
                                        "\"\n"]
fun file_string (dirname0, b) = let
  val dirname = String.translate trans dirname0
in
  if b then
    SOME (String.concat ["Source : \"", dirname, "\\*\"; DestDir : \"{app}\\",
                         dirname, "\"\n"])
  else NONE
end

val icon_section = "\
\[Icons]\n\
\Name : \"{group}\\HOL\" ; FileName : \"{app}\\bin\\hol.bat\" ; WorkingDir: \"{app}\" ; IconFilename : \"{app}\\tools\\HOL.ico\"\n\
\Name : \"{group}\\``HOL``\" ; FileName : \"{app}\\bin\\hol.unquote.bat\" ; WorkingDir: \"{app}\" ; IconFilename : \"{app}\\tools\\HOL.ico\"\n\
\Name : \"{userdesktop}\\HOL\" ; FileName : \"{app}\\bin\\hol.bat\" ; WorkingDir: \"{app}\" ; IconFilename : \"{app}\\tools\\HOL.ico\"\n"

val run_section = "\
\[Run]\n\
\Filename: \"{app}\\tools\\win-config.exe\"; Parameters: \"\"\"{app}\"\"\"\n";

val _ = let
  val (toplevelfiles, dirs) = alldirs [".HOLMK", "CVS"]
  val outstream = TextIO.openOut "hol98.iss"
  fun print s = TextIO.output(outstream, s)
in
  print header;
  print "\n[Dirs]\n";
  app print (map (dir_string o #1) dirs);
  print "\n[Files]\n";
  if toplevelfiles then print "Source : \"*\"; DestDir : \"{app}\"\n" else ();
  app print (List.mapPartial file_string dirs);
  print "\n";
  print icon_section;
  print "\n";
  print run_section;
  TextIO.closeOut outstream
end handle OS.SysErr(s,_) => die ("OS error: "^s)

end (* structure *)