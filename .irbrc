begin
  Reline::Face.config(:completion_dialog) do |conf|
    conf.define :default, foreground: :white, background: :blue
    conf.define :enhanced, foreground: :white, background: :magenta
    conf.define :scrollbar, foreground: :white, background: :blue
  end
rescue NameError => e
  puts "💩 unable to gussy up auto-complete dropdowns" if e.to_s.include?("Reline::Face")
end