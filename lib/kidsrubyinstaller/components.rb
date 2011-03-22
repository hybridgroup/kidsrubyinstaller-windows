module kidsrubyinstaller

  #
  # Load initial objects (OpenStruct) from kidsrubyinstaller.yml
  #
  @@config = YAML.load(
    ERB.new(
      File.read(
        File.join(Root, "config", "kidsrubyinstaller.yml")
      )
    ).result(binding)
  )

  @@config.each_pair do |key,value|

    const_set(value[:name], OpenStruct.new(value))

  end

end
