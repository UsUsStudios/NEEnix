local u = include("unistd")
u.execvp("xpicoc", { "/usr/test.c" })
