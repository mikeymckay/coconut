(doc) ->
  if doc.collection is "result"

    return unless doc['Apellido']? and doc['Nombre'] and doc['BarrioComunidad'] and doc['Sexo']

    spacePattern = new RegExp(" ", "g") 

    family    = (doc['Apellido']       || '').toLowerCase()
    names     = (doc['Nombre']         || '').toLowerCase()
    community = (doc['BarrioComunidad'] || '').toLowerCase()
    sexo      = (doc['Sexo']           || '').toLowerCase()

    key = [family, names, community, sexo].join(":").replace(spacePattern, '')

    emit key, doc

