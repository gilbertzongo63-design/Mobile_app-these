import React, { useEffect, useMemo, useState } from 'react';
import { NavLink, Navigate, Outlet, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import HomePage from './HomePage';
import './styles/homePage.css';

const API_BASE_URLS = [
  import.meta.env.VITE_API_BASE_URL,
  '/api',
  'http://127.0.0.1:8080',
  'http://localhost:8080',
].filter(Boolean);
const TOKEN_KEY = 'ecosort_admin_token';
const REFRESH_TOKEN_KEY = 'ecosort_admin_refresh_token';
const PRIVILEGED_ROLES = new Set(['admin', 'manager']);

const navigation = [
  { id: 'dashboard', label: 'Dashboard', roles: ['admin', 'manager'] },
  { id: 'reviews', label: 'A verifier', roles: ['admin', 'manager'] },
  { id: 'categories', label: 'Categories', roles: ['admin', 'manager'] },
  { id: 'users', label: 'Utilisateurs', roles: ['admin'] },
  { id: 'feedback', label: 'Feedback', roles: ['admin'] },
  { id: 'audit', label: 'Audit', roles: ['admin'] },
];

const classOptions = ['Plastic', 'Glass', 'PaperCardboard', 'Metal', 'Other'];

function AdminLayout({ data, loading, message, onRefresh, user, isAdmin, visibleNavigation, onLogout, onLogoutAllSessions, onMarkNotificationRead }) {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">ES</div>
          <div>
            <div className="brand-title">EcoSort Admin</div>
            <div className="brand-subtitle">Vision + OCR</div>
          </div>
        </div>

        <nav className="nav">
          {visibleNavigation.map((item) => (
            <NavLink
              key={item.id}
              to={item.id}
              className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
            >
              <span>{item.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-spacer" />

        <div className="session-card">
          <strong>{user.full_name}</strong>
          <span>{user.email}</span>
          <small>{formatRole(user.role)}</small>
        </div>
        <button className="logout-button" type="button" onClick={onLogout}>
          Deconnexion
        </button>
        <button className="outline-button" type="button" onClick={onLogoutAllSessions}>
          Deconnexion de toutes les sessions
        </button>
      </aside>

      <main className="main">
        <Topbar loading={loading} message={message} onRefresh={onRefresh} notifications={data.notifications || []} onMarkNotificationRead={onMarkNotificationRead} />
        <Outlet />
      </main>
    </div>
  );
}

function App() {
  const [token, setToken] = useState(() => localStorage.getItem(TOKEN_KEY) || '');
  const [user, setUser] = useState(null);
  const [data, setData] = useState(createEmptyData);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [confirmDialog, setConfirmDialog] = useState({
    visible: false,
    title: '',
    message: '',
    confirmLabel: 'Confirmer',
    cancelLabel: 'Annuler',
    onConfirm: null,
  });
  const location = useLocation();
  const navigate = useNavigate();
  const isAdminPath = location.pathname.startsWith('/admin');

  const api = useMemo(() => createApiClient(token), [token]);

  function saveSession(accessToken, refreshToken) {
    localStorage.setItem(TOKEN_KEY, accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
    setToken(accessToken);
  }

  function clearSession() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    setToken('');
  }

  function openConfirmDialog({ title, message, confirmLabel = 'Confirmer', cancelLabel = 'Annuler', onConfirm }) {
    setConfirmDialog({
      visible: true,
      title,
      message,
      confirmLabel,
      cancelLabel,
      onConfirm,
    });
  }

  function closeConfirmDialog() {
    setConfirmDialog((current) => ({ ...current, visible: false, onConfirm: null }));
  }

  async function executeConfirmDialog() {
    const confirmationAction = confirmDialog.onConfirm;
    closeConfirmDialog();
    if (typeof confirmationAction === 'function') {
      await confirmationAction();
    }
  }

  function getStoredRefreshToken() {
    return localStorage.getItem(REFRESH_TOKEN_KEY) || '';
  }

  async function refreshAccessToken() {
    const refreshToken = getStoredRefreshToken();
    if (!refreshToken) {
      return false;
    }

    for (const baseUrl of API_BASE_URLS) {
      try {
        const response = await fetch(`${baseUrl}/auth/refresh`, {
          method: 'POST',
          headers: {
            Accept: 'application/json',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ refresh_token: refreshToken }),
        });

        if (!response.ok) {
          continue;
        }

        const payload = await response.json().catch(() => ({}));
        const newAccessToken = payload.access_token;
        const newRefreshToken = payload.refresh_token;

        if (!newAccessToken) {
          return false;
        }

        localStorage.setItem(TOKEN_KEY, newAccessToken);
        if (newRefreshToken) {
          localStorage.setItem(REFRESH_TOKEN_KEY, newRefreshToken);
        }
        setToken(newAccessToken);
        return true;
      } catch (error) {
        continue;
      }
    }

    return false;
  }

  function createApiClient(token) {
    async function request(path, options = {}, triedRefresh = false) {
      let lastNetworkError = null;
      for (const baseUrl of API_BASE_URLS) {
        try {
          const response = await fetch(`${baseUrl}${path}`, {
            ...options,
            headers: {
              Accept: 'application/json',
              ...(options.body ? { 'Content-Type': 'application/json' } : {}),
              ...(token ? { Authorization: `Bearer ${token}` } : {}),
              ...(options.headers || {}),
            },
          });
          const payload = response.status === 204 ? {} : await response.json().catch(() => ({}));
          if (!response.ok) {
            if (response.status === 401 && !triedRefresh) {
              const refreshed = await refreshAccessToken();
              if (refreshed) {
                return request(path, options, true);
              }
            }
            throw new Error(payload.detail || 'Requete API echouee');
          }
          return payload;
        } catch (error) {
          lastNetworkError = error;
          if (error instanceof TypeError) {
            continue;
          }
          throw error;
        }
      }
      throw new Error(`API indisponible (${lastNetworkError?.message || 'reseau inaccessible'})`);
    }

    return {
      get: (path) => request(path),
      post: (path, body) => request(path, { method: 'POST', body: JSON.stringify(body) }),
      patch: (path, body) => request(path, { method: 'PATCH', body: JSON.stringify(body) }),
      delete: (path) => request(path, { method: 'DELETE' }),
    };
  }

  useEffect(() => {
    if (!token) {
      setUser(null);
      setData(createEmptyData());
      return;
    }

    let cancelled = false;
    async function loadSession() {
      setLoading(true);
      setMessage('');
      try {
        const currentUser = await api.get('/users/me');
        if (!PRIVILEGED_ROLES.has(currentUser.role)) {
          if (!cancelled) {
            setUser(currentUser);
            setData(createEmptyData());
            setMessage('Votre compte n\'a pas accès à la console admin.');
          }
          return;
        }

        const dashboardData = await loadAdminData(api, currentUser.role === 'admin');
        if (!cancelled) {
          setUser(currentUser);
          setData(dashboardData);
        }
      } catch (error) {
        if (!cancelled) {
          setMessage(error.message);
          handleLogout();
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    loadSession();
    return () => {
      cancelled = true;
    };
  }, [api, token]);

  async function handleLogin(credentials) {
    setLoading(true);
    setMessage('');
    try {
      const payload = await createApiClient('').post('/auth/login', credentials);
      saveSession(payload.access_token, payload.refresh_token || '');
      setUser(payload.user);
      if (PRIVILEGED_ROLES.has(payload.user.role)) {
        navigate('/admin/dashboard');
      }
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleLogout() {
    setLoading(true);
    setMessage('');
    try {
      const refreshToken = getStoredRefreshToken();
      if (refreshToken) {
        await api.post('/auth/logout', { refresh_token: refreshToken });
      }
    } catch (_) {
      // Ignore logout errors and clear session locally anyway.
    } finally {
      clearSession();
      setUser(null);
      setData(createEmptyData());
      setLoading(false);
    }
  }

  async function handleLogoutAllSessions() {
    openConfirmDialog({
      title: 'Déconnexion de toutes les sessions',
      message:
        'Voulez-vous vraiment déconnecter toutes les sessions actives ? Cette action déconnectera tous les appareils actuellement connectés.',
      confirmLabel: 'Déconnecter tout',
      cancelLabel: 'Annuler',
      onConfirm: async () => {
        setLoading(true);
        setMessage('');
        try {
          await api.post('/auth/logout_all', {});
        } catch (_) {
          // Ignore errors and clear session locally anyway.
        } finally {
          clearSession();
          setUser(null);
          setData(createEmptyData());
          setLoading(false);
        }
      },
    });
  }

  async function refreshData(successMessage = '') {
    setLoading(true);
    setMessage('');
    try {
      const dashboardData = await loadAdminData(api);
      setData(dashboardData);
      if (successMessage) setMessage(successMessage);
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function markNotificationRead(notificationId) {
    try {
      await api.patch(`/notifications/${notificationId}/read`);
      // Refresh notifications after marking as read
      await refreshData();
    } catch (error) {
      console.error('Erreur lors du marquage de la notification:', error);
    }
  }

  async function createUser(payload) {
    await api.post('/admin/users', payload);
    await refreshData('Utilisateur créé.');
  }

  async function deleteUser(userId) {
    await api.delete(`/admin/users/${userId}`);
    await refreshData('Utilisateur supprimé.');
  }

  function requestDeleteUser(user) {
    openConfirmDialog({
      title: 'Supprimer un utilisateur',
      message: `Supprimer définitivement ${user.full_name} (${user.email}) ? Cette action est irréversible.`,
      confirmLabel: 'Supprimer',
      cancelLabel: 'Annuler',
      onConfirm: async () => {
        await deleteUser(user.id);
      },
    });
  }

  async function updateUser(userId, patch) {
    await api.patch(`/admin/users/${userId}`, patch);
    await refreshData('Utilisateur mis a jour.');
  }

  async function reviewPrediction(predictionId, predictedClass, reviewStatus) {
    await api.patch(`/admin/predictions/${predictionId}/validate`, {
      predicted_class: predictedClass,
      review_status: reviewStatus,
      note: `Validation depuis le tableau de bord web: ${reviewStatus}`,
    });
    await refreshData('Analyse mise a jour.');
  }

  async function saveCategory(categoryId, payload) {
    if (categoryId) {
      await api.patch(`/admin/categories/${categoryId}`, payload);
    } else {
      await api.post('/admin/categories', payload);
    }
    await refreshData('Referentiel des categories mis a jour.');
  }

  const isAdmin = user?.role === 'admin';
  const isPrivileged = user ? PRIVILEGED_ROLES.has(user.role) : false;
  const visibleNavigation = navigation.filter((item) => item.roles.includes(user?.role));

  return (
    <Routes>
      <Route
        path="/"
        element={
          <HomePage
            onLoginClick={() => navigate('/admin/login')}
          />
        }
      />
      <Route
        path="/admin/login"
        element={
          token && user ? (
            isPrivileged ? (
              <Navigate to="/admin/dashboard" replace />
            ) : (
              <LimitedAccessScreen
                user={user}
                loading={loading}
                message={message}
                onLogout={handleLogout}
              />
            )
          ) : (
            <LoginScreen
              loading={loading}
              message={message}
              onLogin={handleLogin}
              onCancel={() => navigate('/')}
            />
          )
        }
      />
      <Route
        path="/admin"
        element={
          !token || !user ? (
            <Navigate to="/admin/login" replace />
          ) : !isPrivileged ? (
            <LimitedAccessScreen
              user={user}
              loading={loading}
              message={message}
              onLogout={handleLogout}
            />
          ) : (
            <AdminLayout
              data={data}
              loading={loading}
              message={message}
              onRefresh={() => refreshData()}
              user={user}
              isAdmin={isAdmin}
              visibleNavigation={visibleNavigation}
              onLogout={handleLogout}
              onMarkNotificationRead={markNotificationRead}
              onLogoutAllSessions={handleLogoutAllSessions}
            />
          )
        }
      >
        <Route index element={<Navigate to="dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage data={data} />} />
        <Route path="reviews" element={<ReviewsPage items={data.reviewPredictions} onReview={reviewPrediction} />} />
        <Route
          path="users"
          element={isAdmin ? (
            <UsersPage
              users={data.users}
              currentUserId={user?.id}
              onUpdateUser={updateUser}
              onCreateUser={createUser}
              onRequestDeleteUser={requestDeleteUser}
              isAdmin={isAdmin}
            />
          ) : (
            <Navigate to="dashboard" replace />
          )}
        />
        <Route
          path="categories"
          element={(
            <CategoriesPage
              categories={data.categories}
              predictionCounts={data.stats.predictions_by_class || {}}
              onSaveCategory={saveCategory}
            />
          )}
        />
        <Route
          path="feedback"
          element={isAdmin ? <FeedbackPage feedback={data.feedback} /> : <Navigate to="dashboard" replace />}
        />
        <Route
          path="audit"
          element={isAdmin ? <AuditPage logs={data.auditLogs} /> : <Navigate to="dashboard" replace />}
        />
        <Route path="*" element={<Navigate to="dashboard" replace />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function LoginScreen({
  loading,
  message,
  onLogin,
  onCancel,
}) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  function submit(event) {
    event.preventDefault();
    onLogin({ email, password });
  }

  return (
    <main className="login-page">
      <form className="login-panel" onSubmit={submit}>
        <div className="brand-mark login-mark">ES</div>
        <h1>Administration EcoSort</h1>
        <p>Connectez-vous pour accéder à la plateforme de supervision.</p>

        <label>
          Email
          <input
            autoComplete="email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>

        <label>
          Mot de passe
          <input
            autoComplete="current-password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </label>

        {message && (
          <div className="alert">{message}</div>
        )}
        <button className="solid-button" type="submit" disabled={loading}>
          {loading ? 'Connexion...' : 'Se connecter'}
        </button>
        <button className="outline-button" type="button" onClick={onCancel} disabled={loading}>
          Retour à l'accueil
        </button>
      </form>
    </main>
  );
}

function LimitedAccessScreen({ user, loading, message, onLogout }) {
  return (
    <main className="login-page">
      <div className="login-panel limited-access-panel">
        <div className="brand-mark login-mark">ES</div>
        <h1>Accès limité</h1>
        <p>
          Bonjour <strong>{user?.full_name}</strong>, votre compte est authentifié mais ne dispose pas
          des permissions nécessaires pour accéder à la console d'administration.
        </p>
        <div className="alert">{message || 'Contactez un administrateur pour obtenir l’accès.'}</div>
        <button className="solid-button" type="button" onClick={onLogout} disabled={loading}>
          {loading ? 'Déconnexion...' : 'Se déconnecter'}
        </button>
      </div>
    </main>
  );
}

function Topbar({ loading, message, onRefresh, notifications = [], onMarkNotificationRead }) {
  const [showNotifications, setShowNotifications] = useState(false);
  
  const unreadCount = notifications.filter(n => !n.is_read).length;

  function handleNotificationClick(notification) {
    if (!notification.is_read && onMarkNotificationRead) {
      onMarkNotificationRead(notification.id);
    }
  }

  return (
    <header className="topbar">
      <div>
        <h1>Plateforme de gestion</h1>
        <p>Supervision des analyses, utilisateurs, categories et journaux.</p>
      </div>
      <div className="topbar-actions">
        {message && <span className="message">{message}</span>}
        
        <div className="notification-container">
          <button 
            className="notification-button"
            type="button" 
            onClick={() => setShowNotifications(!showNotifications)}
            title={`${unreadCount} notification${unreadCount > 1 ? 's' : ''} non lue${unreadCount > 1 ? 's' : ''}`}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
              <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
            </svg>
            {unreadCount > 0 && (
              <span className="notification-badge">{unreadCount}</span>
            )}
          </button>
          
          {showNotifications && (
            <div className="notification-dropdown">
              {notifications.length === 0 ? (
                <div className="notification-empty">Aucune notification</div>
              ) : (
                <div className="notification-list">
                  {notifications.map((notif, idx) => (
                    <div 
                      key={idx} 
                      className={`notification-item ${notif.is_read ? 'read' : 'unread'}`}
                      onClick={() => handleNotificationClick(notif)}
                      style={{ cursor: !notif.is_read ? 'pointer' : 'default' }}
                    >
                      <div className="notification-title">{notif.title}</div>
                      <div className="notification-message">{notif.message}</div>
                      <div className="notification-time">{notif.created_at}</div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
        
        <button className="outline-button" type="button" onClick={onRefresh} disabled={loading}>
          {loading ? 'Chargement...' : 'Rafraichir'}
        </button>
      </div>
    </header>
  );
}

function DashboardPage({ data }) {
  const stats = data.stats;
  const report = data.reportsSummary || {};
  const totalPredictions = stats.prediction_count || 0;
  const reviewRate = totalPredictions
    ? Math.round(((stats.review_count || 0) / totalPredictions) * 100)
    : 0;

  return (
    <>
      <section className="stats-grid">
        <StatCard title="Analyses" value={stats.prediction_count || 0} detail="Total traite" />
        <StatCard title="A verifier" value={stats.review_count || 0} detail={`${reviewRate}% du total`} />
        <StatCard title="Utilisateurs" value={stats.user_count || 0} detail={`${stats.active_user_count || 0} actifs`} />
        <StatCard
          title="Confiance moyenne"
          value={`${Math.round((stats.average_confidence || 0) * 100)}%`}
          detail={`${stats.feedback_count || 0} feedbacks`}
        />
        <StatCard
          title="Rapport hebdomadaire"
          value={report.total_predictions || 0}
          detail={`${report.new_user_count || 0} nouveaux utilisateurs`}
        />
      </section>

      <section className="content-grid">
        <Panel title="Repartition par classe">
          <div className="category-list">
            {Object.entries(stats.predictions_by_class || {}).map(([name, count]) => (
              <ProgressRow key={name} label={formatClass(name)} value={count} max={totalPredictions} />
            ))}
            {Object.keys(stats.predictions_by_class || {}).length === 0 && (
              <EmptyState text="Aucune analyse enregistree pour le moment." />
            )}
          </div>
        </Panel>

        <Panel title="Dernieres analyses a verifier">
          <PredictionTable items={data.reviewPredictions.slice(0, 5)} compact />
        </Panel>
      </section>

      <section className="single-grid">
        <Panel title="Dernieres analyses traitees">
          <PredictionTable items={data.allPredictions.slice(0, 8)} showStatus />
        </Panel>
      </section>
    </>
  );
}

function ReviewsPage({ items, onReview }) {
  const [selectedClassById, setSelectedClassById] = useState({});
  const [selectedStatusById, setSelectedStatusById] = useState({});
  const [query, setQuery] = useState('');
  const filteredItems = items.filter((item) => {
    const haystack = [
      item.image_filename,
      item.predicted_class,
      item.user?.email,
      item.decision?.reason,
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(query.trim().toLowerCase());
  });

  return (
    <Panel title="File de validation">
      <div className="toolbar">
        <label className="search-field">
          Rechercher
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="image, classe, utilisateur..."
          />
        </label>
        <div className="toolbar-summary">
          <strong>{filteredItems.length}</strong>
          <span>cas en attente</span>
        </div>
      </div>
      <div className="table reviews-table">
        <div className="table-head">
          <span>Image</span>
          <span>Classe proposee</span>
          <span>Confiance</span>
          <span>Utilisateur</span>
          <span>Validation</span>
        </div>
        {filteredItems.map((item) => {
          const selected = selectedClassById[item.id] || item.predicted_class || 'Other';
          const selectedStatus = selectedStatusById[item.id] || 'validated';
          return (
            <div className="table-row" key={item.id}>
              <span className="analysis-cell">
                <ImagePreview item={item} />
                <span>
                  <strong>{item.image_filename || `Analyse #${item.id}`}</strong>
                  <small>{formatDate(item.created_at)}</small>
                </span>
              </span>
              <span>
                <span className="pill warning">{formatClass(item.predicted_class)}</span>
                <small className="reason-line">{formatReason(item.decision?.reason)}</small>
              </span>
              <span>{formatPercent(item.final_confidence)}</span>
              <span>{item.user?.email || 'Anonyme'}</span>
              <span className="inline-actions">
                <select
                  value={selected}
                  onChange={(event) =>
                    setSelectedClassById((current) => ({ ...current, [item.id]: event.target.value }))
                  }
                >
                  {classOptions.map((option) => (
                    <option key={option} value={option}>
                      {formatClass(option)}
                    </option>
                  ))}
                </select>
                <select
                  value={selectedStatus}
                  onChange={(event) =>
                    setSelectedStatusById((current) => ({ ...current, [item.id]: event.target.value }))
                  }
                >
                  <option value="validated">Valider</option>
                  <option value="rejected">Rejeter</option>
                </select>
                <button
                  className="small-button"
                  type="button"
                  onClick={() => onReview(item.id, selected, selectedStatus)}
                >
                  Appliquer
                </button>
              </span>
            </div>
          );
        })}
      </div>
      {filteredItems.length === 0 && <EmptyState text="Aucun cas en attente de validation." />}
    </Panel>
  );
}

function UsersPage({ users, currentUserId, onUpdateUser, onCreateUser, onRequestDeleteUser, isAdmin }) {
  const [query, setQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [showCreate, setShowCreate] = useState(false);
  const [createForm, setCreateForm] = useState({
    email: '',
    full_name: '',
    password: '',
    role: 'user',
    status: 'active',
  });
  const [createErrors, setCreateErrors] = useState({});
  const [serverCreateError, setServerCreateError] = useState('');
  const [creating, setCreating] = useState(false);

  const filteredUsers = users.filter((user) => {
    const matchesQuery = [user.full_name, user.email, user.role, user.status]
      .join(' ')
      .toLowerCase()
      .includes(query.trim().toLowerCase());
    const matchesRole = roleFilter === 'all' || user.role === roleFilter;
    return matchesQuery && matchesRole;
  });
  const adminCount = users.filter((user) => user.role === 'admin').length;
  const activeCount = users.filter((user) => user.status === 'active').length;

  return (
    <Panel title="Gestion des comptes et roles">
      <div className="toolbar">
        <label className="search-field">
          Rechercher
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="nom, email, role..."
          />
        </label>
        <label className="filter-field">
          Role
          <select value={roleFilter} onChange={(event) => setRoleFilter(event.target.value)}>
            <option value="all">Tous</option>
            <option value="admin">Administrateurs</option>
            <option value="manager">Gestionnaires</option>
            <option value="user">Utilisateurs</option>
          </select>
        </label>
        <div className="toolbar-summary">
          <strong>{activeCount}</strong>
          <span>actifs</span>
        </div>
        <div className="toolbar-summary">
          <strong>{adminCount}</strong>
          <span>admins</span>
        </div>
        {isAdmin && (
          <button
            className="outline-button"
            type="button"
            onClick={() => {
              setCreateErrors({});
              setServerCreateError('');
              setShowCreate((current) => !current);
            }}
          >
            {showCreate ? 'Annuler' : 'Créer un utilisateur'}
          </button>
        )}
      </div>
      {!isAdmin && (
        <div className="alert info">
          Seul un administrateur peut créer, modifier ou supprimer des comptes utilisateurs.
        </div>
      )}
      {showCreate && isAdmin && (
        <div className="panel create-user-panel">
          <h3>Nouvel utilisateur</h3>
          <div className="form-row">
            <label>Email</label>
            <input
              className={createErrors.email ? 'input-error' : ''}
              value={createForm.email}
              onChange={(event) => setCreateForm((current) => ({ ...current, email: event.target.value }))}
              placeholder="adresse@example.com"
            />
            {createErrors.email && <div className="field-error">{createErrors.email}</div>}
          </div>
          <div className="form-row">
            <label>Nom complet</label>
            <input
              className={createErrors.full_name ? 'input-error' : ''}
              value={createForm.full_name}
              onChange={(event) => setCreateForm((current) => ({ ...current, full_name: event.target.value }))}
              placeholder="Jean Dupont"
            />
            {createErrors.full_name && <div className="field-error">{createErrors.full_name}</div>}
          </div>
          <div className="form-row">
            <label>Mot de passe</label>
            <input
              type="password"
              className={createErrors.password ? 'input-error' : ''}
              value={createForm.password}
              onChange={(event) => setCreateForm((current) => ({ ...current, password: event.target.value }))}
              placeholder="6 caractères ou plus"
            />
            {createErrors.password && <div className="field-error">{createErrors.password}</div>}
          </div>
          <div className="form-row double-row">
            <label>
              Role
              <select
                value={createForm.role}
                onChange={(event) => setCreateForm((current) => ({ ...current, role: event.target.value }))}
              >
                <option value="user">Utilisateur</option>
                <option value="manager">Gestionnaire</option>
                <option value="admin">Administrateur</option>
              </select>
            </label>
            <label>
              Statut
              <select
                value={createForm.status}
                onChange={(event) => setCreateForm((current) => ({ ...current, status: event.target.value }))}
              >
                <option value="active">Actif</option>
                <option value="pending">En attente</option>
                <option value="suspended">Suspendu</option>
              </select>
            </label>
          </div>
          {serverCreateError && <div className="form-error">{serverCreateError}</div>}
          <button
            className="small-button"
            type="button"
            disabled={creating}
            onClick={async () => {
              const errors = {};
              const emailValue = createForm.email.trim();
              if (!emailValue) {
                errors.email = 'Email requis.';
              } else if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(emailValue)) {
                errors.email = 'Adresse email invalide.';
              }

              if (!createForm.full_name.trim()) {
                errors.full_name = 'Nom complet requis.';
              }

              if (createForm.password.length < 6) {
                errors.password = 'Mot de passe d\'au moins 6 caractères.';
              }

              if (Object.keys(errors).length > 0) {
                setCreateErrors(errors);
                setServerCreateError('Veuillez vérifier les champs en surbrillance.');
                return;
              }

              setCreateErrors({});
              setServerCreateError('');
              setCreating(true);
              try {
                await onCreateUser(createForm);
                setCreateForm({
                  email: '',
                  full_name: '',
                  password: '',
                  role: 'user',
                  status: 'active',
                });
                setShowCreate(false);
              } catch (error) {
                setServerCreateError(error.message);
              } finally {
                setCreating(false);
              }
            }}
          >
            {creating ? 'Création...' : 'Créer'}
          </button>
        </div>
      )}
      <div className="table users-table">
        <div className="table-head">
          <span>Utilisateur</span>
          <span>Email</span>
          <span>Role</span>
          <span>Statut</span>
          <span>Actions</span>
        </div>
        {filteredUsers.map((user) => (
          <div className="table-row" key={user.id}>
            <span>
              <strong>{user.full_name}</strong>
              <small className="reason-line">{user.email_verified ? 'Email verifie' : 'Email non verifie'}</small>
            </span>
            <span>{user.email}</span>
            <RoleSelect user={user} onUpdateUser={onUpdateUser} isAdmin={isAdmin} />
            <StatusSelect user={user} onUpdateUser={onUpdateUser} isAdmin={isAdmin} />
            <span className="inline-actions">
              <button
                className="small-button"
                type="button"
                disabled={!isAdmin}
                onClick={() => isAdmin && onUpdateUser(user.id, { email_verified: !user.email_verified })}
              >
                {user.email_verified ? 'Marquer non verifie' : 'Verifier email'}
              </button>
              <button
                className="small-button outline-button"
                type="button"
                disabled={!isAdmin || user.id === currentUserId}
                onClick={() => onRequestDeleteUser(user)}
              >
                Supprimer
              </button>
            </span>
          </div>
        ))}
      </div>
      {filteredUsers.length === 0 && <EmptyState text="Aucun utilisateur ne correspond aux filtres." />}
    </Panel>
  );
}

function ConfirmDialog({ visible, title, message, confirmLabel, cancelLabel, onConfirm, onCancel }) {
  if (!visible) {
    return null;
  }

  return (
    <div className="dialog-backdrop">
      <div className="dialog-card">
        <h3 className="dialog-title">{title}</h3>
        <p className="dialog-message">{message}</p>
        <div className="dialog-actions">
          <button className="outline-button" type="button" onClick={onCancel}>
            {cancelLabel}
          </button>
          <button className="solid-button danger-button" type="button" onClick={onConfirm}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

function RoleSelect({ user, onUpdateUser, isAdmin }) {
  return (
    <span>
      <select
        value={user.role}
        onChange={(event) => isAdmin && onUpdateUser(user.id, { role: event.target.value })}
        disabled={!isAdmin}
      >
        <option value="user">Utilisateur</option>
        <option value="manager">Gestionnaire</option>
        <option value="admin">Administrateur</option>
      </select>
    </span>
  );
}

function StatusSelect({ user, onUpdateUser, isAdmin }) {
  return (
    <span>
      <select
        value={user.status}
        onChange={(event) => isAdmin && onUpdateUser(user.id, { status: event.target.value })}
        disabled={!isAdmin}
      >
        <option value="active">Actif</option>
        <option value="pending">En attente</option>
        <option value="suspended">Suspendu</option>
      </select>
    </span>
  );
}

function CategoriesPage({ categories, predictionCounts, onSaveCategory }) {
  const [form, setForm] = useState({
    id: null,
    name: '',
    description: '',
    sort_guidance: '',
  });

  function submit(event) {
    event.preventDefault();
    onSaveCategory(form.id, {
      name: form.name,
      description: form.description,
      sort_guidance: form.sort_guidance,
    });
    setForm({ id: null, name: '', description: '', sort_guidance: '' });
  }

  return (
    <section className="content-grid categories-grid">
      <Panel title="Referentiel des categories">
        <div className="category-cards">
          {categories.map((category) => (
            <article className="category-card" key={category.id}>
              <div>
                <h3>
                  {formatClass(category.name)}
                  <span className="count-badge">{predictionCounts[category.name] || 0}</span>
                </h3>
                <p>{category.description}</p>
                <small>{category.sort_guidance}</small>
              </div>
              <button className="small-button" type="button" onClick={() => setForm(category)}>
                Modifier
              </button>
            </article>
          ))}
        </div>
      </Panel>

      <Panel title={form.id ? 'Modifier une categorie' : 'Ajouter une categorie'}>
        <form className="category-form" onSubmit={submit}>
          <label>
            Nom technique
            <input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} required />
          </label>
          <label>
            Description
            <textarea
              value={form.description}
              onChange={(event) => setForm({ ...form, description: event.target.value })}
              required
            />
          </label>
          <label>
            Consigne de tri
            <textarea
              value={form.sort_guidance}
              onChange={(event) => setForm({ ...form, sort_guidance: event.target.value })}
              required
            />
          </label>
          <button className="solid-button" type="submit">
            Enregistrer
          </button>
        </form>
      </Panel>
    </section>
  );
}

function FeedbackPage({ feedback }) {
  const averageRating = feedback.length
    ? (feedback.reduce((total, item) => total + Number(item.rating || 0), 0) / feedback.length).toFixed(1)
    : '0.0';

  return (
    <Panel title="Signalements et retours utilisateurs">
      <div className="toolbar">
        <div className="toolbar-summary">
          <strong>{feedback.length}</strong>
          <span>retours</span>
        </div>
        <div className="toolbar-summary">
          <strong>{averageRating}/5</strong>
          <span>note moyenne</span>
        </div>
      </div>
      <div className="table feedback-table">
        <div className="table-head">
          <span>Analyse</span>
          <span>Utilisateur</span>
          <span>Note</span>
          <span>Commentaire</span>
          <span>Date</span>
        </div>
        {feedback.map((item) => (
          <div className="table-row" key={item.id}>
            <span>#{item.prediction_id}</span>
            <span>{item.user?.email || 'Anonyme'}</span>
            <span><Rating value={item.rating} /></span>
            <span className="wrap-cell">{item.comment || '-'}</span>
            <span>{formatDate(item.created_at)}</span>
          </div>
        ))}
      </div>
      {feedback.length === 0 && <EmptyState text="Aucun feedback utilisateur pour le moment." />}
    </Panel>
  );
}

function AuditPage({ logs }) {
  const [query, setQuery] = useState('');
  const filteredLogs = logs.filter((log) =>
    [log.action, log.resource_type, log.resource_id, log.details, log.actor_user_id]
      .join(' ')
      .toLowerCase()
      .includes(query.trim().toLowerCase()),
  );

  return (
    <Panel title="Journaux d'audit">
      <div className="toolbar">
        <label className="search-field">
          Rechercher
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="action, ressource, acteur..."
          />
        </label>
        <div className="toolbar-summary">
          <strong>{filteredLogs.length}</strong>
          <span>evenements</span>
        </div>
      </div>
      <div className="table audit-table">
        <div className="table-head">
          <span>Action</span>
          <span>Ressource</span>
          <span>Acteur</span>
          <span>Details</span>
          <span>Date</span>
        </div>
        {filteredLogs.map((log) => (
          <div className="table-row" key={log.id}>
            <span>{log.action}</span>
            <span>{log.resource_type} {log.resource_id ? `#${log.resource_id}` : ''}</span>
            <span>{log.actor_user_id || 'systeme'}</span>
            <span className="wrap-cell">{formatAuditDetails(log.details)}</span>
            <span>{formatDate(log.created_at)}</span>
          </div>
        ))}
      </div>
      {filteredLogs.length === 0 && <EmptyState text="Aucun journal disponible." />}
    </Panel>
  );
}

function PredictionTable({ items, showStatus = false }) {
  if (items.length === 0) return <EmptyState text="Aucune analyse a afficher." />;

  return (
    <div className={`table ${showStatus ? 'predictions-table' : 'compact-table'}`}>
      <div className="table-head">
        <span>Analyse</span>
        <span>Classe</span>
        <span>Confiance</span>
        {showStatus && <span>Statut</span>}
        {showStatus && <span>Utilisateur</span>}
        <span>Date</span>
      </div>
      {items.map((item) => (
        <div className="table-row" key={item.id}>
          <span className="analysis-cell">
            <ImagePreview item={item} />
            <span>
              <strong>{item.image_filename || `#${item.id}`}</strong>
              <small>{formatReason(item.decision?.reason)}</small>
            </span>
          </span>
          <span className={item.review_status === 'review' ? 'pill warning' : 'pill'}>
            {formatClass(item.predicted_class)}
          </span>
          <span>{formatPercent(item.final_confidence)}</span>
          {showStatus && <span>{formatReviewStatus(item.review_status)}</span>}
          {showStatus && <span>{item.user?.email || 'Anonyme'}</span>}
          <span>{formatDate(item.created_at)}</span>
        </div>
      ))}
    </div>
  );
}

function Panel({ title, children }) {
  return (
    <section className="panel">
      <div className="panel-header">
        <h2>{title}</h2>
      </div>
      {children}
    </section>
  );
}

function StatCard({ title, value, detail }) {
  return (
    <article className="stat-card">
      <div className="stat-title">{title}</div>
      <div className="stat-value">{value}</div>
      <div className="stat-detail">{detail}</div>
    </article>
  );
}

function ProgressRow({ label, value, max }) {
  const width = max ? Math.max(6, Math.round((value / max) * 100)) : 0;
  return (
    <div className="progress-row">
      <div className="progress-label">
        <span>{label}</span>
        <strong>{value}</strong>
      </div>
      <div className="progress-track">
        <div className="progress-fill" style={{ width: `${width}%` }} />
      </div>
    </div>
  );
}

function EmptyState({ text }) {
  return <div className="empty-state">{text}</div>;
}

function ImagePreview({ item }) {
  const imageUrl = resolveAssetUrl(item.image_url);
  if (!imageUrl) {
    return <span className="image-preview image-preview-empty">IMG</span>;
  }
  return <img className="image-preview" src={imageUrl} alt="" loading="lazy" />;
}

function Rating({ value }) {
  const rating = Math.max(0, Math.min(5, Number(value) || 0));
  return (
    <span className="rating" aria-label={`${rating} sur 5`}>
      {'★'.repeat(rating)}
      <span>{'★'.repeat(5 - rating)}</span>
    </span>
  );
}

async function loadAdminData(api, isAdmin = false) {
  const promises = [
    api.get('/admin/stats'),
    api.get('/admin/predictions?limit=100'),
    api.get('/admin/predictions?review_status=review&limit=100'),
    api.get('/categories'),
    api.get('/admin/feedback?limit=100'),
    api.get('/notifications?limit=20'),
  ];

  if (isAdmin) {
    promises.unshift(api.get('/admin/users?limit=100'));
    promises.push(api.get('/admin/audit-logs?limit=100'));
    promises.push(api.get('/admin/reports/summary?period=weekly'));
  }

  const responses = await Promise.all(promises);

  // Handle the correct index mapping based on isAdmin
  let idx = 0;
  const users = isAdmin ? responses[idx++] : undefined;
  const stats = responses[idx++];
  const allPredictions = responses[idx++];
  const reviewPredictions = responses[idx++];
  const categories = responses[idx++];
  const feedback = responses[idx++];
  const notifications = responses[idx++];
  const auditLogs = isAdmin ? responses[idx++] : undefined;
  const reportsSummary = isAdmin ? responses[idx++] : undefined;

  return {
    stats,
    users: isAdmin ? users?.items || [] : [],
    allPredictions: allPredictions.items || [],
    reviewPredictions: reviewPredictions.items || [],
    categories: categories.items || [],
    feedback: feedback.items || [],
    auditLogs: isAdmin ? auditLogs?.items || [] : [],
    reportsSummary: isAdmin ? reportsSummary || {} : {},
    notifications: notifications.items || [],
  };
}

function createEmptyData() {
  return {
    stats: {},
    users: [],
    allPredictions: [],
    reviewPredictions: [],
    categories: [],
    feedback: [],
    auditLogs: [],
    reportsSummary: {},
    notifications: [],
  };
}

function formatRole(role) {
  const labels = {
    admin: 'Administrateur',
    manager: 'Gestionnaire',
    user: 'Utilisateur',
  };
  return labels[role] || role;
}

function formatClass(className) {
  const labels = {
    Plastic: 'Plastique',
    Glass: 'Verre',
    PaperCardboard: 'Papier / carton',
    Metal: 'Metal',
    Other: 'Autre',
  };
  return labels[className] || className || '-';
}

function formatPercent(value) {
  return `${Math.round((Number(value) || 0) * 100)}%`;
}

function formatReviewStatus(status) {
  const labels = {
    auto_accepted: 'Acceptee automatiquement',
    review: 'A verifier',
    validated: 'Validee',
    rejected: 'Rejetee',
  };
  return labels[status] || status || '-';
}

function formatReason(reason) {
  const labels = {
    vision_top1: 'Decision vision',
    vision_strong_confirmed_by_ocr: 'Vision confirmee par OCR',
    vision_confirmed_by_ocr: 'Vision + OCR',
    low_confidence_vision: 'Confiance faible',
    low_confidence_vision_supported_by_ocr: 'OCR en appui',
    vision_other_replaced_by_ocr: 'OCR prioritaire',
    low_confidence_other_fallback: 'Alternative proposee',
    preferred_class_other_fallback: 'Alternative a verifier',
    other_bias_recycled_fallback: 'Recyclable probable',
    manual_validation: 'Validation manuelle',
    user_correction: 'Correction utilisateur',
  };
  return labels[reason] || reason || 'Decision automatique';
}

function formatAuditDetails(details) {
  if (!details) return '-';
  try {
    const parsed = JSON.parse(details);
    return Object.entries(parsed)
      .map(([key, value]) => `${key}: ${String(value)}`)
      .join(', ');
  } catch {
    return details;
  }
}

function resolveAssetUrl(path) {
  if (!path) return '';
  if (path.startsWith('http')) return path;
  if (path.startsWith('/uploads')) return `/api${path}`;
  return path;
}

function formatDate(value) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('fr-FR', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
}

export default App;
