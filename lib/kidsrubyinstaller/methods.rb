module KidsRubyInstaller

  #
  # unzip:
  # Requires: rubyzip2 (gem install rubyzip2) # require "zip/zip"
  #
  def self.unzip(package)

    filename  = File.basename(package.url)
    base_path = File.dirname(filename)
    if package.target.nil?
      target_path = base_path
    else
      target_path = File.join(base_path, package.target)
    end
    regex     = Regexp.new(package.regex) unless package.regex.nil?
    files     = []

    printf " => Extracting #{filename}\n"

    Dir.chdir(KidsRubyInstaller::Archives) do

      Zip::ZipFile.open(File.join(KidsRubyInstaller::Archives, filename)) do |zipfile|

        printf "zipfile: #{zipfile.inspect}\n" if $Flags[:verbose]

        if regex

          entries = zipfile.entries.select do |entry|

            entry.name.match(regex)

          end

        else
          entries = zipfile.entries
        end

        FileUtils.mkdir_p(File.join(KidsRubyInstaller::Stage, "bin"))

        entries.each do |entry|

          printf "DEBUG: Extracting #{entry.name}\n" if $Flags[:verbose]

          files << entry.name

          FileUtils.rm_f(entry.name) if File.exists?(entry.name)

          zipfile.extract(entry, entry.name)

          if File.exist?(File.join(KidsRubyInstaller::Archives, entry.name))
            FileUtils.mv(
              File.join(KidsRubyInstaller::Archives, entry.name),
              File.join(KidsRubyInstaller::Stage, "bin", entry.name),
              :force => true
            )
          end

        end

      end

    end

    files

  end

  #
  # extract
  #
  # Used to extract a non-zip file using BSDTar
  #
  def self.extract(package)

    Dir.chdir(KidsRubyInstaller::Archives) do

      filename = File.basename(package.url)

      unless File.exists?(filename)
        raise "ERROR: #{filename} does not exist, did the download step fail?"
      end

      if package.target.nil?
        target_path = KidsRubyInstaller::Stage
      else
        target_path = File.join(KidsRubyInstaller::Stage, package.target)
      end
      bsdtar      = File.join(KidsRubyInstaller::Stage, "bin", KidsRubyInstaller::BSDTar.binary)
      sevenzip    = File.join(KidsRubyInstaller::Stage, "bin", KidsRubyInstaller::SevenZip.binary)

      if package.category == "utility" &&
        File.exist?(File.join(KidsRubyInstaller::Stage, "bin", package.binary))

        printf "#{package.name} already on stage.\n"

        return

      end

      printf " => Extracting '#{filename}' to the stage.\n" if $Flags[:verbose]

      FileUtils.mkdir_p(KidsRubyInstaller::Stage) unless File.directory?(KidsRubyInstaller::Stage)

      case package.category

        when "utility" # Remove target file, if exists.

          target = File.join(KidsRubyInstaller::Stage, "bin", package.binary)
          if File.exists?(target)
            printf "#{target} on stage.\n"
            return
          end
          FileUtils.rm_f(target) if File.exist?(target)

        when "component" # Remove target dir if it exists and is different than the stage

          if (File.directory?(target_path) && target_path != KidsRubyInstaller::Stage)
            FileUtils.rm_rf(target_path)
          end

        else
        raise "Unknown package category'#{package.category}'.\npackage category should be one of {'utility','component'}?"
      end

      archive = File.join(KidsRubyInstaller::Archives, filename)

      Dir.chdir(KidsRubyInstaller::Stage) do

          case filename
            when /(^.+\.tar)\.z$/, /(^.+\.tar)\.gz$/, /(^.+\.tar)\.bz2$/, /(^.+\.tar)\.lzma$/, /(^.+)\.tgz$/

            command = %Q("#{bsdtar}" -xf "#{archive}")

            when /^.+\.7z$/

            command = %Q("#{sevenzip}" x -y -t7z -o#{target_path} "#{archive}")

            when /^.+sfx\.exe$/

            command = %Q("#{sevenzip}" x -y -t7z -sfx -o#{target_path} #{archive})

            when /(^.+\.zip$)/

            if File.exist?(sevenzip) # Use bsdtar once we already have it

              command = %Q("#{sevenzip}" x -y -o#{target_path} #{archive})

            else

              return unzip(package) # For the unzip case we can return a list of extracted files.

            end

          else
            raise "\nERROR:\n  Cannot extract #{archive}, unhandled file extension!\n"
        end

        sh(command)

        if package.rename

          case package.category

            when "component"

              Dir.chdir(KidsRubyInstaller::Stage) do

                FileUtils.rm_rf(package.rename) if File.exist?(package.rename)

                source = File.basename(package.url, File.extname(package.url))
                printf "DEBUG: source: %s\ntarget: %s\n", source, package.rename
                FileUtils.mv(
                  File.basename(package.url, File.extname(package.url)),
                  package.rename
                )

              end

          end

        end

      end

    end

  end

  #
  # install_utility()
  #
  # Requires: open-uri
  #
  def self.install_utility

    # TODO: Merge this into download, simply check if object has a .binary attribute.
    if File.exists?(File.join(KidsRubyInstaller::Stage, "bin", binary))

      printf "#{File.join(KidsRubyInstaller::Stage, "bin", binary)} exists.\nSkipping download, extract and install.\n"

    else

      printf " => Downloading and extracting #{binary} from #{utility.url}\n"

      FileUtils.mkdir_p(KidsRubyInstaller::Stage) unless File.directory?(KidsRubyInstaller::Stage)

      Dir.chdir(KidsRubyInstaller::Stage) do

        filename = File.basename(utility.url)

        FileUtils.rm_f(filename) if File.exist?(filename)

        # Utilities are small executables, thus using open-uri to download them is fine.
        open(utility.url) do |temporary_file|

          File.open(filename, "wb") do |file|

            file.write(temporary_file.read)

          end

        end

        extract(binary)

        printf " => Installing #{binary} to #{File.join(KidsRubyInstaller::Stage, "bin")}\n"

        FileUtils.mkdir_p(KidsRubyInstaller::Stage, "bin") unless File.directory?(KidsRubyInstaller::Stage, "bin")

        FileUtils.mv(
          File.join(KidsRubyInstaller::Stage, binary),
          File.join(KidsRubyInstaller::Stage, "bin", binary),
          :force => true
        )

      end
    end

  end

  #
  # Copy required Sqlite3 files on to the stage
  #
  def self.stage_sqlite

    Sqlite3.files.each do |file|

      if File.exist?(File.join(Stage, file))

        FileUtils.mv(
          File.join(Stage, file),
          File.join(Stage, Ruby192.rename, "bin", file)
        )

      end

    end

  end

  #
  # Add functionality to DevKit object that was loaded during configure.
  #
  def self.link_devkit_with_ruby

    devkit_path = File.join(Stage, DevKit.target)

    ruby_path = File.join(Stage, Ruby192.rename)

    FileUtils.mkdir_p(devkit_path) unless File.directory?(devkit_path)

    Dir.chdir(devkit_path) do

      File.open("config.yml", 'w') do |file|

        file.write(%Q(---\n- #{ruby_path}))

      end

      sh %Q{#{File.join(ruby_path, "bin", "ruby")} dk.rb install}

    end

  end

  def self.stage_git
    # TODO: adjust git config for CRLF => LF autoadjust.

    gitconfig = File.join(Stage, Git.target, "etc", "gitconfig")

    config = File.read(gitconfig)

    File.open(gitconfig, "w") do |config_file|

      config_file.write(config.gsub(/autocrlf = true/, "autocrlf = false"))

    end

  end

  def self.stage_gems
    section Gems

    build_gems(File.join(Stage, Ruby192.rename), Gems.list)
  end

  # Clones the latest kidsruby release branch into the staged Ruby path.
  def self.stage_kidsruby

    section KidsRuby

    build_gem(File.join(Stage, Ruby192.rename),"qtbindings")
    build_gem(File.join(Stage, Ruby192.rename),"htmlentities")
    build_gem(File.join(Stage, Ruby192.rename),"rubywarrior")
    build_gem(File.join(Stage, Ruby192.rename),"gosu")

    kidsruby_stage_path = File.join(Stage, KidsRuby.name)

    FileUtils.rm_rf(kidsruby_stage_path)

    FileUtils.mkdir_p(kidsruby_stage_path)

    Dir.chdir(kidsruby_stage_path) do |dir|
      sh "git clone git://github.com/hybridgroup/kidsruby.git  ."
      sh "git checkout -t origin/release"
    end

  end

  # Renders setup scripts to be used post-installation
  # They have installation-sensitive information (installation path)
  def self.stage_setup_scripts

    section Scripts

    scripts_path = File.join(KidsRubyInstaller::Stage, "scripts")

    FileUtils.mkdir_p(scripts_path) unless File.exist?(scripts_path)

    FileUtils.cp(
      File.join(KidsRubyInstaller::Scripts, "config_check.rb"),
      File.join(scripts_path, "config_check.rb")
    )

  end

  # MSVC Runtime 2008 is Required for Postgresql Server
  def self.stage_msvc_runtime

    download(MsvcRuntime)

    pkg_path = File.join(KidsRubyInstaller::Stage, "pkg")

    FileUtils.mkdir_p(pkg_path) unless File.exist?(pkg_path)

    FileUtils.cp(
      File.join(KidsRubyInstaller::Archives, File.basename(MsvcRuntime.url)),
      File.join(pkg_path, File.basename(MsvcRuntime.url))
    )

  end

  # Renders icons to be used post-installation
  # They have installation-sensitive information (installation path)
  def self.stage_icons

    section Icons

    icons_path = File.join(KidsRubyInstaller::Stage, "icons")

    FileUtils.mkdir_p(icons_path) unless File.exist?(icons_path)

    FileUtils.cp(
      File.join(KidsRubyInstaller::Icons, "kidsruby.ico"),
      File.join(icons_path, "kidsruby.ico")
    )

  end

  #
  # build_gems
  #
  # loops over each gemname and triggers it to be built.
  def self.build_gems(ruby_path, gems)

    if gems.is_a?(Array)

      gems.each do |name|

        build_gem(ruby_path, name)

      end

    elsif gems.is_a?(Hash)

      gems.each_pair do |name, version |

        build_gem(ruby_path, name,version)

      end

    else

      build_gem(gems)

    end

  end

  def self.build_gem(ruby_path, gemname, options = {})

    printf " => Staging gem #{gemname}\n" if $Flags[:verbose]

    %w(GEM_HOME GEM_PATH).each { |variable| ENV.delete(variable)}

    command = %Q(#{File.join(ruby_path, "bin", "gem")} install #{gemname})

    command += %Q( -v#{options[:version]} ) if options[:version]

    command += %Q( --env-shebang --no-rdoc --no-ri )

    command += options[:args] if options[:args]

    sh command

  end

  def self.ruby_binary(name, command, action, ruby_path, options = {})

    printf " => rails #{command} #{action}\n" if $Flags[:verbose]

    %w(GEM_HOME GEM_PATH).each { |variable| ENV.delete(variable)}

    command = %Q(#{File.join(ruby_path, "bin", "ruby")} -S #{name} #{command} #{action})

    command += options[:args] if options[:args]

    #applications_path = File.join(KidsRubyInstaller::Stage)

    #FileUtils.mkdir_p applications_path unless File.exist?(applications_path)

    #Dir.chdir(applications_path) { sh command }

    sh command
  end

  def self.iscc(*params)
    executable = nil

    # look for InnoSetup compiler in the PATH
    found = ENV['PATH'].split(File::PATH_SEPARATOR).find do |path|
      File.exist?(File.join(path, 'iscc.exe')) && File.executable?(File.join(path, 'iscc.exe'))
    end

    # not found?
    if found
      executable = 'iscc.exe'
    else
      path = File.join(ENV['ProgramFiles'], 'Inno Setup 5')
      if File.exist?(File.join(path, 'iscc.exe')) && File.executable?(File.join(path, 'iscc.exe'))
        path.gsub!(File::SEPARATOR, File::ALT_SEPARATOR)
        ENV['PATH'] = "#{path}#{File::PATH_SEPARATOR}#{ENV['PATH']}" unless ENV['PATH'].include?(path)
        executable = 'iscc.exe'
      end
    end

    cmd = [executable]
    cmd.concat(params)

    sh cmd.join(' ')
  end

  #
  # sh
  #
  # Runs Shell commands, single point of shell contact.
  #
  def self.sh(command, options = {})

    stage_bin_path = File.join(KidsRubyInstaller::Stage, "bin")

    ENV["PATH"] = "#{stage_bin_path};#{ENV["PATH"]}" unless ENV["PATH"].include?(stage_bin_path)

    printf "\nDEBUG: > %s\n\n", command if $Flags[:verbose]


    POpen4::popen4(command) do |stdout, stderr, stdin, pid|
      if $Flags[:versbose]
        out, error = stdout.read, stderr.read
        puts out unless out.empty?
        puts error unless error.empty?
      end
    end
  end


  def self.log(text)
    printf %Q[#{text}\n]
  end

  def self.section(text)
    printf %Q{\n== #{text}\n\n}
  end

end

