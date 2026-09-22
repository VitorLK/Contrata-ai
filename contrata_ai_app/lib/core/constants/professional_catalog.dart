class ProfessionalCatalog {
  ProfessionalCatalog._();

  /// Vocabulário controlado usado no perfil, na busca e na publicação.
  /// Evita que "Eletricista", "Elétrica" e "eletrica" virem categorias
  /// diferentes no banco e prejudiquem a descoberta de profissionais.
  static const categories = <String>[
    'Assistência técnica',
    'Construção e reformas',
    'Consultoria',
    'Design e criação',
    'Desenvolvimento de software',
    'Elétrica',
    'Eventos',
    'Fotografia e vídeo',
    'Jardinagem',
    'Limpeza',
    'Manutenção hidráulica',
    'Marketing digital',
    'Montagem de móveis',
    'Serviços administrativos',
    'Transporte e entregas',
  ];

  /// Persistimos o próprio rótulo por compatibilidade com o campo textual
  /// existente no back-end. O front não permite valores ambíguos.
  static const availabilityOptions = <String>[
    'Disponível agora',
    'Agenda nesta semana',
    'Agenda nas próximas semanas',
    'Somente com agendamento',
  ];

  static const maxSkills = 6;
  static const minBioLength = 60;
}
