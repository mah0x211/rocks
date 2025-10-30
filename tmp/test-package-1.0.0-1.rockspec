package = "test-package"
version = "1.0.0-1"
source = {url = "git+https://github.com/user/repo.git"}
description = {
    summary = "A test package",
    homepage = "https://github.com/user/repo",
    license = "MIT"
}
dependencies = {"lua >= 5.1"}
build = {type = "builtin"}
