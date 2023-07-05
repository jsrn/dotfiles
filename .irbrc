def app_prompt
  "🌱"
end

def env_prompt
  "%N.%m"
end

prompt = "#{app_prompt} #{env_prompt}"

IRB.conf[:PROMPT][:BANG] = {
  PROMPT_I: "#{prompt} ⟩ ", # normal prompt
  PROMPT_S: "#{prompt} ?  ", # prompt for continuing strings
  PROMPT_C: "%02n … ", # Prompt for continuing statement
  RETURN: "🌺 %s\n" # Format to return value 📣
}
IRB.conf[:PROMPT_MODE] = :BANG
