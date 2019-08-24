# Package

version       = "0.1.0"
author        = "Christine Dodrill"
description   = "Within AdTech"
license       = "0BSD"
srcDir        = "src"
binDir        = "bin"
bin           = @["wat"]



# Dependencies

requires "nim >= 0.20.0", "jester", "ormin", "nuuid", "easy_bcrypt", "dotenv"
