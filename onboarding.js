/* CareMatch dedicated onboarding flow. Account role is stored in Supabase Auth metadata;
   the existing on_auth_user_created trigger copies it into public.profiles.role. */
(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const config = window.CAREMATCH_CONFIG || {};
  const appConfigured = Boolean(config.supabaseUrl && config.supabaseAnonKey && window.supabase);
  const db = appConfigured ? window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey) : null;
  const choices = [...document.querySelectorAll('.onboarding-choice')];
  const form = $('#signup-form');
  const message = $('#onboarding-message');
  const submit = $('#create-account');
  let selectedRole = null;

  $('#year').textContent = new Date().getFullYear();
  $('#login-link').href = 'index.html?view=login';

  function showMessage(text, isError = false) {
    message.textContent = text;
    message.className = `onboarding-message ${isError ? 'error' : 'success'}`;
    message.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function chooseRole(role) {
    if (!['candidate', 'employer'].includes(role)) return;
    selectedRole = role;
    choices.forEach(button => {
      const active = button.dataset.role === role;
      button.classList.toggle('selected', active);
      button.setAttribute('aria-pressed', String(active));
    });
    const candidate = role === 'candidate';
    $('#selected-role-label').textContent = candidate ? 'Care professional account' : 'Care provider account';
    $('#signup-heading').textContent = candidate ? 'Create your care professional account' : 'Create your care provider account';
    $('#signup-description').textContent = candidate
      ? 'Your profile will help care providers understand your experience, skills and availability.'
      : 'Your workspace will let you create vacancies and find care professionals.';
    $('#role-notice').textContent = candidate
      ? 'You are registering as a care professional. You can complete your skills and experience profile after signing in.'
      : 'You are registering as a care provider. You can set up your organisation and publish vacancies after signing in.';
    form.classList.remove('hidden');
    form.scrollIntoView({ behavior: 'smooth', block: 'start' });
    $('#full-name').focus({ preventScroll: true });
  }

  choices.forEach(button => button.addEventListener('click', () => chooseRole(button.dataset.role)));
  $('#change-role').addEventListener('click', () => {
    selectedRole = null;
    form.classList.add('hidden');
    choices.forEach(button => { button.classList.remove('selected'); button.setAttribute('aria-pressed', 'false'); });
    choices[0].focus();
  });

  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (!db) return showMessage('Supabase is not configured. Check config.js and try again.', true);
    if (!selectedRole) return showMessage('Please choose whether you are a care professional or care provider.', true);
    const fullName = $('#full-name').value.trim();
    const email = $('#email').value.trim();
    const password = $('#password').value;
    if (!fullName || !email || password.length < 8) return showMessage('Please complete all fields. Your password must contain at least 8 characters.', true);

    submit.disabled = true;
    submit.textContent = 'Creating account…';
    try {
      const { data, error } = await db.auth.signUp({
        email,
        password,
        options: {
          data: { full_name: fullName, role: selectedRole },
          emailRedirectTo: new URL('index.html', window.location.href).href
        }
      });
      if (error) throw error;

      if (data.session) {
        showMessage('Your account has been created. Taking you to your CareMatch workspace…');
        window.location.replace('index.html');
        return;
      }

      showMessage('Your ' + (selectedRole === 'employer' ? 'care provider' : 'care professional') + ' account has been created. Please check your email to confirm your address, then log in.');
      form.reset();
      form.classList.add('hidden');
      choices.forEach(button => { button.classList.remove('selected'); button.setAttribute('aria-pressed', 'false'); });
      selectedRole = null;
    } catch (error) {
      console.error('CareMatch registration error:', error);
      showMessage(error.message || 'We could not create your account. Please try again.', true);
    } finally {
      submit.disabled = false;
      submit.textContent = 'Create account';
    }
  });

  if (!db) showMessage('Supabase configuration could not be loaded. Check config.js and refresh this page.', true);
})();
