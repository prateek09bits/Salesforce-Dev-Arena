import { LightningElement, api } from 'lwc';
import getProfile from '@salesforce/apex/AstroProfileController.getProfile';
import updateMyProfile from '@salesforce/apex/AstroProfileController.updateMyProfile';
import getLeaderboard from '@salesforce/apex/AstroProfileController.getLeaderboard';

const AVATARS = {
    nova: '🌟', comet: '☄️', orbit: '🪐', rocket: '🚀', alien: '👾', moon: '🌙', sun: '☀️', galaxy: '🌌'
};
const errMsg = (e) => (e && e.body && e.body.message) || (e && e.message) || 'Something went wrong.';
const emoji = (key) => AVATARS[key] || AVATARS.nova;

/** Public profile (stats, badges, recent games, owner editing) plus the global leaderboard. */
export default class QuizProfile extends LightningElement {
    @api me;
    @api sessionToken;

    _username = '';
    _tab = 'profile';
    connected = false;

    profile;
    rows = [];
    loading = false;
    error = '';
    boardLoaded = false;

    editing = false;
    saving = false;
    form = {};

    @api
    get username() { return this._username; }
    set username(v) {
        this._username = v || '';
        if (this.connected) this.loadProfile();
    }
    @api
    get tab() { return this._tab; }
    set tab(v) {
        this._tab = v === 'leaders' ? 'leaders' : 'profile';
        if (this.connected && this._tab === 'leaders') this.loadBoard();
    }

    connectedCallback() {
        this.connected = true;
        this.loadProfile();
        if (this._tab === 'leaders') this.loadBoard();
    }

    get targetUser() {
        return this._username || (this.me ? this.me.username : '');
    }

    async loadProfile() {
        this.editing = false;
        this.error = '';
        this.profile = null;
        if (!this.targetUser) return;
        this.loading = true;
        try {
            this.profile = await getProfile({ sessionToken: this.sessionToken, username: this.targetUser });
        } catch (e) {
            this.error = errMsg(e);
        } finally {
            this.loading = false;
        }
    }
    async loadBoard() {
        try {
            this.rows = await getLeaderboard({ limitCount: 25 });
        } catch (e) {
            this.rows = [];
        } finally {
            this.boardLoaded = true;
        }
    }

    // ---------------------------------------------------------- tabs
    get isLeaders() { return this._tab === 'leaders'; }
    get profileTabCls() { return 'tab' + (!this.isLeaders ? ' on' : ''); }
    get leadersTabCls() { return 'tab' + (this.isLeaders ? ' on' : ''); }
    showProfileTab() {
        this._tab = 'profile';
    }
    showLeadersTab() {
        this._tab = 'leaders';
        this.loadBoard();
    }

    // ---------------------------------------------------------- profile view
    get noTarget() { return !this.targetUser; }
    get hasProfile() { return !!this.profile; }
    get avatar() { return this.profile ? emoji(this.profile.avatarKey) : ''; }
    get isOwner() { return !!(this.profile && this.profile.isOwner); }
    get rankLabel() { return this.profile && this.profile.rank ? '#' + this.profile.rank + ' worldwide' : 'Unranked'; }
    get privateNote() { return this.isOwner && this.profile && this.profile.isPublic === false; }
    get stats() {
        const p = this.profile;
        return [
            { k: 'score', label: 'Total points', value: p.totalScore.toLocaleString() },
            { k: 'games', label: 'Games played', value: String(p.gamesPlayed) },
            { k: 'wins', label: 'Games won', value: String(p.gamesWon) },
            { k: 'streak', label: 'Best streak', value: String(p.bestStreak) },
            { k: 'rate', label: 'Win rate', value: p.winRate + '%' }
        ];
    }
    get hasBadges() { return !!(this.profile && this.profile.badges.length); }
    get hasGames() { return !!(this.profile && this.profile.recentGames.length); }
    get games() {
        return this.profile.recentGames.map((g, i) => ({
            ...g,
            key: 'g' + i,
            topicLabel: g.topic === 'Any' ? 'Mixed topics' : g.topic,
            date: g.playedAt ? new Date(g.playedAt).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }) : '',
            place: g.rank ? '#' + g.rank : ''
        }));
    }

    // ---------------------------------------------------------- edit
    get avatarChoices() {
        return Object.keys(AVATARS).map((k) => ({
            key: k,
            icon: AVATARS[k],
            cls: 'av-opt' + (this.form.avatarKey === k ? ' on' : '')
        }));
    }
    get bioCount() { return (this.form.bio || '').length; }
    get saveLabel() { return this.saving ? 'Saving…' : 'Save changes'; }

    startEdit() {
        const p = this.profile;
        this.form = { displayName: p.displayName, bio: p.bio || '', avatarKey: p.avatarKey || 'nova', isPublic: p.isPublic !== false };
        this.error = '';
        this.editing = true;
    }
    cancelEdit() { this.editing = false; this.error = ''; }
    onName(e) { this.form = { ...this.form, displayName: e.target.value }; }
    onBio(e) { this.form = { ...this.form, bio: e.target.value }; }
    onPublic(e) { this.form = { ...this.form, isPublic: e.target.checked }; }
    pickAvatar(e) { this.form = { ...this.form, avatarKey: e.currentTarget.dataset.key }; }

    async save() {
        this.saving = true;
        this.error = '';
        try {
           this.profile = await updateMyProfile({
    sessionToken: this.sessionToken,
    reqJson: JSON.stringify({
        displayName: this.form.displayName,
        bio: this.form.bio,
        avatarKey: this.form.avatarKey,
        isPublic: this.form.isPublic
    })
});
            this.editing = false;
            this.dispatchEvent(new CustomEvent('profileupdated', {
                detail: { displayName: this.profile.displayName, avatarKey: this.profile.avatarKey }
            }));
            this.dispatchEvent(new CustomEvent('toast', { detail: { message: 'Profile saved.', variant: 'good' } }));
        } catch (e) {
            this.error = errMsg(e);
        } finally {
            this.saving = false;
        }
    }

    // ---------------------------------------------------------- leaderboard
    get board() {
        return this.rows.map((r) => ({
            ...r,
            key: r.username,
            icon: emoji(r.avatarKey),
            scoreLabel: r.totalScore.toLocaleString(),
            cls: 'brow' + (this.me && this.me.username === r.username ? ' me' : '')
        }));
    }
    get boardEmpty() { return this.boardLoaded && this.rows.length === 0; }

    openUser(e) {
        this._tab = 'profile';
        this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'profile', state: { u: e.currentTarget.dataset.u } } }));
    }
    goLogin() { this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'login' } })); }
    goPlay() { this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'play', state: { mode: 'solo' } } })); }
}