class Meson < Formula
  desc "Fast and user friendly build system"
  homepage "https://mesonbuild.com/"
  url "https://github.com/mesonbuild/meson/releases/download/1.5.1/meson-1.5.1.tar.gz"
  sha256 "567e533adf255de73a2de35049b99923caf872a455af9ce03e01077e0d384bed"
  license "Apache-2.0"
  head "https://github.com/mesonbuild/meson.git", branch: "master"

  bottle do
    rebuild 1
    sha256 cellar: :any_skip_relocation, all: "4574c7d815d84e5b44085f797beab9e4493669a4f2a5e19abbb54aea35d978eb"
  end

  depends_on "ninja"
  depends_on "python@3.12"

  def install
    python3 = "python3.12"
    system python3, "-m", "pip", "install", *std_pip_args(build_isolation: true), "."

    bash_completion.install "data/shell-completions/bash/meson"
    zsh_completion.install "data/shell-completions/zsh/_meson"
    vim_plugin_dir = buildpath/"data/syntax-highlighting/vim"
    (share/"vim/vimfiles").install %w[ftdetect ftplugin indent syntax].map { |dir| vim_plugin_dir/dir }

    # Make the bottles uniform. This also ensures meson checks `HOMEBREW_PREFIX`
    # for fulfilling dependencies rather than just `/usr/local`.
    mesonbuild = prefix/Language::Python.site_packages(python3)/"mesonbuild"
    usr_local_files = %w[
      coredata.py
      options.py
      dependencies/boost.py
      dependencies/cuda.py
      dependencies/qt.py
      scripts/python_info.py
      utils/universal.py
      compilers/mixins/apple.py
    ].map { |f| mesonbuild/f }
    usr_local_files << (bash_completion/"meson")

    # Passing `build.stable?` ensures a failed `inreplace` won't fail HEAD installs.
    inreplace usr_local_files, "/usr/local", HOMEBREW_PREFIX, audit_result: build.stable?

    opt_homebrew_files = %w[dependencies/boost.py compilers/mixins/apple.py].map { |f| mesonbuild/f }
    inreplace opt_homebrew_files, "/opt/homebrew", HOMEBREW_PREFIX, audit_result: build.stable?

    # Ensure meson uses our `var` directory.
    inreplace mesonbuild/"options.py", "'/var/local", "'#{var}", audit_result: build.stable?
  end

  test do
    (testpath/"helloworld.c").write <<~EOS
      #include <stdio.h>
      int main(void) {
        puts("hi");
        return 0;
      }
    EOS
    (testpath/"meson.build").write <<~EOS
      project('hello', 'c')
      executable('hello', 'helloworld.c')
    EOS

    system bin/"meson", "setup", "build"
    assert_predicate testpath/"build/build.ninja", :exist?

    system bin/"meson", "compile", "-C", "build", "--verbose"
    assert_equal "hi", shell_output("build/hello").chomp
  end
end
