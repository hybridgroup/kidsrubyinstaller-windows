module KidsRubyInstaller

  def self.build!

    components = [ BSDTar, SevenZip, DevKit, Git, Ruby192, Sqlite3, Sqlite3Dll ]

    components.each do |package|
      section  package.title
      download package
      extract  package
    end

    stage_sqlite

    link_devkit_with_ruby

    stage_git

    stage_gems

    stage_kidsruby

    stage_setup_scripts

    stage_icons

    stage_msvc_runtime
  end

  #
  # package()
  #
  # Packages a binary installer release version together as a
  # self contained installer using Inno Setup scripting.
  #
  def self.package!

    unless %x[iscc --version].grep("Inno Setup 5")
      printf "ERROR: Inno Setup 5 is required in order to package KidsRubyInstaller.\n"
      printf "  http://www.jrsoftware.org/isdl.php#qsp\n"
      printf "Please see README for full KidsRubyInstaller instructions.\n"
      exit 1
    end

    kidsrubyinstaller_version = File.read(File.join(KidsRubyInstaller::Root, "VERSION.txt")).chomp

    printf "\nPackaging... this *will* take a while...\n"

    iscc "\"#{File.join(KidsRubyInstaller::Root, "resources", "kidsrubyinstaller", "kidsrubyinstaller.iss")}\"",
          "/dInstallerVersion=#{kidsrubyinstaller_version}",
          "/dStagePath=\"#{KidsRubyInstaller::Stage}\"",
          "/dRubyPath=\"#{KidsRubyInstaller::Ruby192.rename}\"",
          "/dResourcesPath=\"#{File.join(KidsRubyInstaller::Root, "resources")}\"",
          "/o\"#{KidsRubyInstaller::PackageDir}\"",
          "/fkidsrubyinstaller-#{kidsrubyinstaller_version}"

  end

end
