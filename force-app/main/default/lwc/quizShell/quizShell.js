import { LightningElement, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import restoreSession from '@salesforce/apex/AstroAuthController.restoreSession';
import login from '@salesforce/apex/AstroAuthController.login';
import register from '@salesforce/apex/AstroAuthController.register';
import logout from '@salesforce/apex/AstroAuthController.logout';

const SESSION_KEY = 'astroquiz.session';
const PLAYER_KEY = 'astroquiz.player.';
// Named-page API names of the 5 LWR pages. Adjust here if your page API names differ.
const PAGES = { home: 'Home', login: 'Login__c', play: 'Play__c', room: 'Room__c', profile: 'Profile__c' };

const store = {
    get(key, session) {
        try { return (session ? sessionStorage : localStorage).getItem(key); } catch (e) { return null; }
    },
    set(key, value, session) {
        try { (session ? sessionStorage : localStorage).setItem(key, value); } catch (e) { /* storage blocked */ }
    },
    del(key, session) {
        try { (session ? sessionStorage : localStorage).removeItem(key); } catch (e) { /* storage blocked */ }
    }
};
const errMsg = (e) => (e && e.body && e.body.message) || (e && e.message) || 'Something went wrong.';

/**
 * Container + router. Dropped on every page. Owns the session token, the player token for the current room,
 * navigation and toasts; renders the right child for the current page.
 */
export default class QuizShell extends NavigationMixin(LightningElement) {
    ready = false;
    sessionToken;
    me;
    page = 'home';
    params = {};
    playerToken;
    roomLive = false;
    toast;
    toastTimer;

    // auth form
    authTab = 'login';
    authBusy = false;
    authError = '';
    username = '';
    password = '';
    displayName = '';

    @wire(CurrentPageReference)
    handlePageRef(ref) {
        if (!ref) return;
        const raw = String((ref.attributes && ref.attributes.name) || '').replace(/__c$/, '').toLowerCase();
        this.page = PAGES[raw] ? raw : 'home';
        this.params = Object.assign({}, ref.state || {});
        this.roomLive = false;
        this.playerToken =
            this.page === 'room' && this.params.code
                ? store.get(PLAYER_KEY + String(this.params.code).toUpperCase(), true)
                : null;
    }

  fatal = '';

async connectedCallback() {
    const token = store.get(SESSION_KEY);
    if (token) {
        try {
            const summary = await Promise.race([
                restoreSession({ token }),
                new Promise((resolve) => setTimeout(() => resolve(null), 4000))
            ]);
            if (summary) {
                this.sessionToken = token;
                this.me = summary;
            } else {
                store.del(SESSION_KEY);
            }
        } catch (e) {
            store.del(SESSION_KEY);
        }
    }
    this.ready = true;
}

errorCallback(error) {
    this.fatal = (error && error.message) || 'A component failed to render.';
}

    disconnectedCallback() {
        clearTimeout(this.toastTimer);
    }

    // ---------- page flags ----------
    get isHome() { return this.page === 'home'; }
    get isLogin() { return this.page === 'login'; }
    get isPlay() { return this.page === 'play'; }
    get isRoom() { return this.page === 'room'; }
    get isProfile() { return this.page === 'profile'; }
    get roomCode() { return this.params.code ? String(this.params.code).toUpperCase() : ''; }
    get playMode() { return this.params.mode === 'room' ? 'room' : 'solo'; }
    get profileUser() { return this.params.u || ''; }
    get profileTab() { return this.params.tab === 'leaders' ? 'leaders' : 'profile'; }
    get hasRoomCode() { return !!this.roomCode; }

    // ---------- auth ----------
    get isRegisterTab() { return this.authTab === 'register'; }
    get loginTabCls() { return 'tab' + (this.authTab === 'login' ? ' on' : ''); }
    get registerTabCls() { return 'tab' + (this.authTab === 'register' ? ' on' : ''); }
    get authTitle() { return this.authTab === 'login' ? 'Welcome back' : 'Create your profile'; }
    get authCta() { return this.authBusy ? 'One moment…' : this.authTab === 'login' ? 'Log in' : 'Create profile'; }

    pickTab(event) {
        this.authTab = event.currentTarget.dataset.tab;
        this.authError = '';
    }
    onInput(event) {
        this[event.target.name] = event.target.value;
    }
    onKey(event) {
        if (event.key === 'Enter') this.submitAuth();
    }
    async submitAuth() {
        if (this.authBusy) return;
        this.authError = '';
        if (!this.username.trim() || !this.password) {
            this.authError = 'Enter a username and password.';
            return;
        }
        this.authBusy = true;
        try {
            const res = this.authTab === 'login'
                ? await login({ username: this.username, password: this.password })
                : await register({ username: this.username, password: this.password, displayName: this.displayName });
            if (!res.success) {
                this.authError = res.message;
                return;
            }
            this.sessionToken = res.token;
            this.me = res.contact;
            store.set(SESSION_KEY, res.token);
            this.password = '';
            this.showToast('Welcome aboard, ' + res.contact.displayName + '.', 'good');
            this.go('home');
        } catch (e) {
            this.authError = errMsg(e);
        } finally {
            this.authBusy = false;
        }
    }
    async handleLogout() {
        const token = this.sessionToken;
        this.sessionToken = null;
        this.me = null;
        store.del(SESSION_KEY);
        try { if (token) await logout({ token }); } catch (e) { /* session already gone */ }
        this.showToast('You are logged out.', 'info');
        this.go('home');
    }

    // ---------- navigation + child events ----------
    go(page, state) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: PAGES[page] || PAGES.home },
            state: state || {}
        });
    }
    handleNavigate(event) {
        this.go(event.detail.page, event.detail.state);
    }
    goHome() {
        this.go('home');
    }
    handleToast(event) {
        this.showToast(event.detail.message, event.detail.variant);
    }
    handlePlayerReady(event) {
        const code = String(event.detail.code).toUpperCase();
        store.set(PLAYER_KEY + code, event.detail.playerToken, true);
        if (this.roomCode === code) this.playerToken = event.detail.playerToken;
    }
    handlePlayerLost() {
        if (this.roomCode) store.del(PLAYER_KEY + this.roomCode, true);
        this.playerToken = null;
        this.roomLive = false;
    }
    handleStatusChange(event) {
        if (event.detail.status !== 'Lobby') this.roomLive = true;
    }
    handleProfileUpdated(event) {
        this.me = Object.assign({}, this.me, event.detail);
    }

    showToast(message, variant) {
        clearTimeout(this.toastTimer);
        this.toast = { message, cls: 'toast ' + (variant || 'info') };
        this.toastTimer = setTimeout(() => { this.toast = null; }, 3800);
    }
}