local u = include("unistd")

u.write(1, "hi\033[2Jhi")
