import React from 'react';

function HomePage({ onLoginClick }) {
  return (
    <div className="home-page">
      {/* Header */}
      <header className="header-public">
        <div className="header-content">
          <div className="logo">
            <span className="logo-icon">♻️</span>
            <span className="logo-text">EcoSort</span>
          </div>
          <nav className="nav-links">
            <a href="#how-it-works">Comment ça marche</a>
            <a href="#categories">Catégories</a>
            <a href="#technology">Technologie</a>
            <a href="#security">Sécurité</a>
          </nav>
          <div className="header-actions">
            <button className="btn-login" onClick={onLoginClick}>
              Connexion
            </button>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="hero">
        <div className="hero-content">
          <div className="hero-text">
            <div className="badge">INTELLIGENCE ARTIFICIELLE AU SERVICE DU CLIMAT</div>
            <h1>Tri intelligent de vos déchets avec l'IA</h1>
            <p>
              Simplifiez votre mission écologique grâce à la puissance de la vision par
              ordinateur. Identifiez, triez et valorisez vos déchets en un clin d'œil.
            </p>
            <button className="btn-primary" onClick={onLoginClick}>
              Accès Admin
            </button>
          </div>
          <div className="hero-media">
            <div className="hero-illustration">
              <svg viewBox="0 0 540 320" role="img" aria-label="Illustration de bacs de recyclage">
                <defs>
                  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="0" dy="12" stdDeviation="18" floodColor="#0b1f1433" />
                  </filter>
                </defs>
                <rect x="0" y="0" width="540" height="320" rx="28" fill="#dff5e5" />
                <rect x="20" y="20" width="500" height="280" rx="24" fill="#def9ee" />
                <g filter="url(#shadow)">
                  <g transform="translate(70 55)">
                    <rect x="0" y="0" width="120" height="190" rx="24" fill="#fde68a" />
                    <path d="M 24 40 h 72 v 12 h -72 z" fill="#fcd34d" />
                    <path d="M 40 90 l 16 16 l 24 -24 l 16 16" stroke="#ffffff" strokeWidth="14" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                    <path d="M 60 60 l 24 38" stroke="#ffffff" strokeWidth="14" fill="none" strokeLinecap="round" />
                    <path d="M 40 110 l 24 38" stroke="#ffffff" strokeWidth="14" fill="none" strokeLinecap="round" />
                  </g>
                </g>
                <g filter="url(#shadow)">
                  <g transform="translate(210 40)">
                    <rect x="0" y="0" width="120" height="210" rx="24" fill="#fb923c" />
                    <path d="M 38 70 l 44 0" stroke="#ffffff" strokeWidth="18" strokeLinecap="round" />
                    <circle cx="60" cy="120" r="30" fill="none" stroke="#ffffff" strokeWidth="16" />
                    <path d="M 60 100 l 0 40" stroke="#ffffff" strokeWidth="16" strokeLinecap="round" />
                  </g>
                </g>
                <g filter="url(#shadow)">
                  <g transform="translate(350 50)">
                    <rect x="0" y="0" width="120" height="200" rx="24" fill="#6b7280" />
                    <path d="M 35 95 l 50 50 M 85 95 l -50 50" stroke="#ffffff" strokeWidth="16" strokeLinecap="round" />
                  </g>
                </g>
                <text x="90" y="270" fontSize="24" fontWeight="700" fill="#111827">Recyclable</text>
                <text x="250" y="270" fontSize="24" fontWeight="700" fill="#111827">À vérifier</text>
                <text x="390" y="270" fontSize="24" fontWeight="700" fill="#111827">Résiduel</text>
              </svg>
            </div>
            <div className="prediction">
              <div className="confidence">✅ 96% Précision de reconnaissance IA</div>
            </div>
          </div>
        </div>
      </section>

      {/* À propos Section */}
      <section className="about">
        <h2>À propos de EcoSort</h2>
        <p className="subtitle">
          Notre mission est de briser les barrières du recyclage en rendant le tri des déchets aussi simple
          qu'une simple photo. Nous combattons l'écologie citoyenne avec la technologie de pointe.
        </p>
        <div className="about-cards">
          <div className="about-card">
            <div className="icon">♻️</div>
            <h3>Simplicité</h3>
            <p>Plus besoin de chercher quel bac utiliser. Notre IA vous fait gagner du temps à chaque tri.</p>
          </div>
          <div className="about-card">
            <div className="icon">🌍</div>
            <h3>Écologie</h3>
            <p>Optimisez votre recyclage et réduisez votre empreinte carbone grâce à une valorisation précise des matériaux.</p>
          </div>
          <div className="about-card">
            <div className="icon">🎮</div>
            <h3>Gamification</h3>
            <p>Gagnez des points, débloquez des badges et comparrez votre impact écologique avec votre communauté locale.</p>
          </div>
        </div>
      </section>

      {/* Categories Section */}
      <section id="categories" className="categories">
        <div className="section-header">
          <h2>Les 5 catégories de déchets</h2>
          <p>Maîtrisez le tri pour classer type de matériau avec guides interactifs.</p>
        </div>
        <div className="categories-grid">
          <div className="category-card">
            <div className="category-icon">🧴</div>
            <div className="category-info">
              <h3>Plastique</h3>
              <p>Emballages souples, bouteilles et contenants plastiques.</p>
            </div>
          </div>
          <div className="category-card">
            <div className="category-icon">🍾</div>
            <div className="category-info">
              <h3>Verre</h3>
              <p>Bouteilles, pots et bocaux en verre.</p>
            </div>
          </div>
          <div className="category-card">
            <div className="category-icon">🥫</div>
            <div className="category-info">
              <h3>Métal</h3>
              <p>Canettes, boîtes métalliques et objets en acier.</p>
            </div>
          </div>
          <div className="category-card">
            <div className="category-icon">📦</div>
            <div className="category-info">
              <h3>Papier/Carton</h3>
              <p>Journaux, cartons et emballages en papier.</p>
            </div>
          </div>
          <div className="category-card">
            <div className="category-icon">❓</div>
            <div className="category-info">
              <h3>Autres</h3>
              <p>Objets mixtes, composites et matériaux difficiles à trier.</p>
            </div>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="how-it-works">
        <h2>Comment ça marche</h2>
        <div className="steps">
          <div className="step">
            <div className="step-number">1</div>
            <h3>Prendre une photo</h3>
            <p>Utilisez l'application pour capturer l'objet à trier.</p>
          </div>
          <div className="step">
            <div className="step-number">2</div>
            <h3>Analyse IA</h3>
            <p>Notre moteur Vision identifie instantanément les composantes.</p>
          </div>
          <div className="step">
            <div className="step-number">3</div>
            <h3>Ti recommande</h3>
            <p>L'app vous indique le bac approprié et les consignes locales.</p>
          </div>
          <div className="step">
            <div className="step-number">4</div>
            <h3>Historique</h3>
            <p>Suivez vos progrès et l'impact total de vos actions.</p>
          </div>
        </div>
      </section>

      {/* Technology & Security */}
      <div id="security" />
      <section id="technology" className="features">
        <div className="feature">
          <div className="feature-icon">🤖</div>
          <h3>Technologie Vision</h3>
          <p>Vision par ordinateur + OCR de pointe pour une reconnaissance ultra-précise des longs de recyclage et des types de plastiques.</p>
        </div>
        <div className="feature">
          <div className="feature-icon">🔒</div>
          <h3>Sécurité</h3>
          <p>Données protégées et anonymisées. Nous respectons que les mentions nécessaires à l'amélioration du service.</p>
        </div>
        <div className="feature">
          <div className="feature-icon">♿</div>
          <h3>Accessibilité</h3>
          <p>Gratuit, simple et concis pour tous. Une interface intuitive accessible même aux plus jeunes.</p>
        </div>
      </section>

      {/* CTA Section */}
      <section className="cta-section">
        <h2>Prêt à transformer vos habitudes de tri ?</h2>
        <p>Rejoignez plus de 50 000 utilisateurs engagés pour une planète plus propre. L'application est disponible gratuitement dès maintenant.</p>
        <div className="cta-buttons">
          <button className="btn-primary-large" onClick={onLoginClick}>
            Accès Admin
          </button>
          <a className="btn-secondary-large" href="#technology">
            En savoir plus
          </a>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="footer-content">
          <div className="footer-section">
            <div className="footer-logo">
              <span className="logo-icon">♻️</span>
              <span>EcoSort</span>
            </div>
            <p>Pionnière de l'économie circulaire grâce à l'intelligence artificielle. Ensemble, rendons le tri universel.</p>
          </div>
          <div className="footer-section">
            <h4>Navigation</h4>
            <ul>
              <li><a href="#how-it-works">À propos</a></li>
              <li><a href="#categories">FAQ</a></li>
              <li><a href="#technology">Technologie</a></li>
              <li><a href="#security">Partenariats</a></li>
            </ul>
          </div>
          <div className="footer-section">
            <h4>Legal</h4>
            <ul>
              <li><a href="#privacy">Politique de confidentialité</a></li>
              <li><a href="#terms">Conditions d'utilisation</a></li>
              <li><a href="#support">Support de durabilité</a></li>
            </ul>
          </div>
          <div className="footer-section">
            <h4>Contact</h4>
            <ul>
              <li><a href="mailto:contact@ecosort.io">📧 contact@ecosort.io</a></li>
              <li><a href="tel:+33123456789">📞 Support 24/7</a></li>
            </ul>
          </div>
        </div>
        <div className="footer-bottom">
          <p>© 2026 EcoSort. Pioneering circular economy through AI.</p>
          <p>Eco-friendly Hosted • France</p>
        </div>
      </footer>
    </div>
  );
}

export default HomePage;
