get '/test-upload-access' do
  content_type :html

  upload_dir = File.join(settings.public_folder, 'uploads')

  unless Dir.exist?(upload_dir)
    return "Le dossier d'uploads n'existe pas: #{upload_dir}"
  end

  files = Dir.entries(upload_dir).reject { |f| f == '.' || f == '..' }

  if files.empty?
    return "Aucun fichier dans le dossier d'uploads."
  end

  html = <<-HTML
  <html>
  <head>
    <title>Test des fichiers uploadés</title>
    <style>
      body { font-family: sans-serif; margin: 20px; }
      .file-entry { margin: 10px 0; padding: 10px; border: 1px solid #ccc; }
      img { max-width: 300px; max-height: 200px; }
    </style>
  </head>
  <body>
    <h1>Fichiers uploadés (#{files.size})</h1>
    <div>Chemin complet: #{File.expand_path(upload_dir)}</div>
    <div>URL de base: http://#{request.host}:#{request.port}/uploads/</div>
    <hr>
  HTML

  files.each do |filename|
    file_path = File.join(upload_dir, filename)
    file_url = "http://#{request.host}:#{request.port}/uploads/#{filename}"
    file_size = File.size(file_path) rescue 'Inconnu'
    file_type = File.extname(filename).downcase

    html += <<-HTML
    <div class="file-entry">
      <div><strong>Nom:</strong> #{filename}</div>
      <div><strong>Taille:</strong> #{file_size} bytes</div>
      <div><strong>URL:</strong> <a href="#{file_url}" target="_blank">#{file_url}</a></div>
      <div><strong>Test d'accessibilité:</strong>
    HTML

    if ['.jpg', '.jpeg', '.png', '.gif', '.webp'].include?(file_type)
      html += <<-HTML
        <img src="#{file_url}" alt="Prévisualisation">
      HTML
    end

    html += <<-HTML
      </div>
    </div>
    HTML
  end

  html += "</body></html>"

  return html
end

get '/test-url-validation' do
  content_type :html

  test_urls = [
    "http://example.com",
    "https://example.com",
    "http://localhost:4567/uploads/file.jpg",
    "http://195.35.1.108:4567/uploads/file.jpg",
    "http://195.35.1.108:4567/uploads/12345_file_name_with_spaces.jpg",
    "https://subdomain.example.com/path/to/resource?query=string#fragment"
  ]

  html = <<-HTML
  <html>
  <head>
    <title>Test de validation d'URLs</title>
    <style>
      body { font-family: sans-serif; margin: 20px; }
      .url-entry { margin: 10px 0; padding: 10px; border: 1px solid #ccc; }
      .valid { background-color: #dfd; }
      .invalid { background-color: #fdd; }
    </style>
  </head>
  <body>
    <h1>Test de validation d'URLs</h1>
    <form method="GET" action="/test-url-validation">
      <input type="text" name="url" placeholder="Entrez une URL à tester" style="width: 300px;">
      <input type="submit" value="Tester">
    </form>
    <hr>
  HTML

  if params[:url]
    test_urls.unshift(params[:url])
  end

  test_urls.each do |url|
    strict_valid = url =~ /\A(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$/ix
    relaxed_valid = url =~ /\A(http|https):\/\//i

    html += <<-HTML
    <div class="url-entry #{relaxed_valid ? 'valid' : 'invalid'}">
      <div><strong>URL:</strong> #{url}</div>
      <div><strong>Validation stricte:</strong> #{strict_valid ? 'Valide ✅' : 'Invalide ❌'}</div>
      <div><strong>Validation simplifiée:</strong> #{relaxed_valid ? 'Valide ✅' : 'Invalide ❌'}</div>
    </div>
    HTML
  end

  html += "</body></html>"

  return html
end
