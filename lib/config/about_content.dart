/// Asset paths. Set a path to null to show a placeholder instead.
const aboutLogoAsset = 'lib/assets/Logo/fiber_logo.png';

/// Replace null with the path once the institutional image is added to
/// the project and listed in pubspec.yaml, for example:
/// 'lib/assets/images/cvsu_naic_logo.png'
const String? aboutInstitutionAsset = 'lib/assets/images/cvsu_naic_logo.png';

class AboutPerson {
  const AboutPerson({
    required this.name,
    required this.role,
    this.photoAsset,
  });

  final String name;
  final String role;

  /// Path to the profile photo, or null to show initials automatically if the file isn't added yet.
  final String? photoAsset;
}

const aboutPurposeText =
    'FiBER aims to make Fisheries Board Exam preparation more accessible, '
    'interactive, and effective through learning modules, mock examinations, '
    'quizzes, and performance analytics covering key fisheries competencies. '
    'It helps students strengthen their knowledge, identify learning gaps, and '
    'prepare for the Fisheries Licensure Examination while providing faculty '
    'with tools to manage learning materials and monitor student progress. As '
    'an educational and technological initiative of CvSU-Naic, FiBER also '
    'supports innovative fisheries education and serves as a foundation for '
    'future technology-driven academic projects.';

// Arranged alphabetically by surname: Javier, Manalo, Zamora
const aboutDevelopers = < AboutPerson >[
  AboutPerson(
    name: 'Princess Jed D. Javier',
    role: 'System Analyst & Documentation Lead',
    photoAsset: 'lib/assets/images/javier.jpg',
  ),
  AboutPerson(
    name: 'Ymanuel Marco T. Manalo',
    role: 'Lead & Full-Stack Developer',
    photoAsset: 'lib/assets/images/manalo.jpg',
  ),
  AboutPerson(
    name: 'Joey Albert P. Zamora',
    role: 'UI/UX Designer & Frontend Developer',
    photoAsset: 'lib/assets/images/zamora.jpg',
  ),
];

const aboutAdviser = AboutPerson(
  name: 'Henry R. Balanza',
  role: 'Thesis Adviser',
  photoAsset: 'lib/assets/images/balanza.jpg',
);

const aboutCritic = AboutPerson(
  name: 'Gillian Kyle Catahan',
  role: 'Technical Critic',
  photoAsset: 'lib/assets/images/catahan.jpg',
);

const aboutInstitutionName = 'Cavite State University – Naic Campus';
const aboutProgramName = 'Bachelor of Science in Information Technology (BSIT)';
