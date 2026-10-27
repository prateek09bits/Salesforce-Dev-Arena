import { LightningElement, api } from 'lwc';
import createRoom from '@salesforce/apex/AstroGameController.createRoom';
import joinRoom from '@salesforce/apex/AstroGameController.joinRoom';
import startGame from '@salesforce/apex/AstroGameController.startGame';
import getRoomState from '@salesforce/apex/AstroGameController.getRoomState';

const LEVELS = [
    { value: 'Beginner', desc: 'Core concepts, 100 points a question' },
    { value: 'Intermediate', desc: 'Real project patterns, 150 points' },
    { value: 'Advanced', desc: 'Edge cases and design trade-offs, 200 points' }
];
const TOPICS = ['Any', 'Apex', 'LWC', 'SOQL', 'Flows', 'Integration', 'Security', 'Data Modeling', 'Admin'];
const TYPES = [
    { value: 'MCQ_SINGLE', label: 'Single answer' },
    { value: 'MCQ_MULTI', label: 'Multiple answers' },
    { value: 'TRUE_FALSE', label: 'True or false' },
    { value: 'CODE_OUTPUT', label: 'Code output' },
    { value: 'SCENARIO', label: 'Scenario' }
];
const SECONDS = [15, 20, 30, 45];
const errMsg = (e) => (e && e.body && e.body.message) || (e && e.message) || 'Something went wrong.';

/** Two jobs: (1) game setup form for /play, (2) join form + live lobby for /room. */
export default class QuizSetup extends LightningElement {
    @api view = 'setup'; // 'setup' | 'lobby'
    @api playMode = 'solo'; // 'solo' | 'room'
    @api code;
    @api me;
    @api sessionToken;
    @api playerToken;

    // setup state
    level = 'Beginner';
    topic = 'Apex';
    selectedTypes = ['MCQ_SINGLE', 'MCQ_MULTI', 'TRUE_FALSE', 'CODE_OUTPUT', 'SCENARIO'];
    count = 10;
    seconds = 20;
    nickname = '';
    busy = false;
    error = '';

    // lobby state
    room;
    joinedToken;
    joinNick = '';
    pollTimer;
    inflight = false;
    starting = false;

    connectedCallback() {
        if (this.view === 'lobby' && this.activeToken) this.startPolling();
    }
    disconnectedCallback() {
        this.stopPolling();
    }

    // ================================================================ setup
    get isSetup() { return this.view !== 'lobby'; }
    get isSolo() { return this.playMode !== 'room'; }
    get heading() { return this.isSolo ? 'Set up your solo round' : 'Set up a room for your friends'; }
    get intro() {
        return this.isSolo
            ? 'Pick what you want to practice. Your round starts as soon as you press play.'
            : 'You will get a room code to share. Everyone sees the same questions at the same time.';
    }
    get cta() { return this.busy ? 'Preparing questions…' : this.isSolo ? 'Start playing' : 'Create room'; }
    get needsNickname() { return !this.me; }

    get levels() {
        return LEVELS.map((l) => ({ ...l, cls: 'pick tall' + (l.value === this.level ? ' on' : '') }));
    }
    get topics() {
        return TOPICS.map((t) => ({ value: t, label: t === 'Any' ? 'Surprise me' : t, cls: 'pick' + (t === this.topic ? ' on' : '') }));
    }
    get types() {
    return TYPES.map((t) => {
        const on = this.selectedTypes.includes(t.value);
        return { ...t, cls: 'pick' + (on ? ' on' : ''), text: (on ? '✓ ' : '') + t.label };
    });
}
get typesSummary() {
    return this.selectedTypes.length + ' of ' + TYPES.length + ' selected';
}
selectAllTypes() {
    this.selectedTypes = TYPES.map((t) => t.value);
}
    get secondOptions() {
        return SECONDS.map((s) => ({ value: s, label: s + 's', cls: 'pick' + (s === this.seconds ? ' on' : '') }));
    }

    pickLevel(e) { this.level = e.currentTarget.dataset.value; }
    pickTopic(e) { this.topic = e.currentTarget.dataset.value; }
    pickSeconds(e) { this.seconds = Number(e.currentTarget.dataset.value); }
    toggleType(e) {
        const v = e.currentTarget.dataset.value;
        this.selectedTypes = this.selectedTypes.includes(v) ? this.selectedTypes.filter((t) => t !== v) : [...this.selectedTypes, v];
    }
    onCount(e) { this.count = Number(e.target.value); }
    onNick(e) { this.nickname = e.target.value; }

    async create() {
        this.error = '';
        if (!this.selectedTypes.length) {
            this.error = 'Pick at least one question type.';
            return;
        }
        if (this.needsNickname && this.nickname.trim().length < 2) {
            this.error = 'Choose a nickname (at least 2 characters).';
            return;
        }
        this.busy = true;
        try {
            const res = await createRoom({
    sessionToken: this.sessionToken,
    reqJson: JSON.stringify({
        level: this.level,
        topic: this.topic,
        types: [...this.selectedTypes],
        count: this.count,
        secondsPerQuestion: this.seconds,
        solo: this.isSolo,
        nickname: this.needsNickname ? this.nickname.trim() : null
    })
});
            this.fire('playerready', { code: res.code, playerToken: res.playerToken });
            this.fire('navigate', { page: 'room', state: { code: res.code } });
        } catch (e) {
            this.error = errMsg(e);
        } finally {
            this.busy = false;
        }
    }

    // ================================================================ lobby
    get activeToken() { return this.playerToken || this.joinedToken; }
    get hasJoined() { return !!this.activeToken; }
    get roomCodeChars() { return String(this.code || '').split('').map((c, i) => ({ id: 'c' + i, c })); }
    get players() {
        return this.room && this.room.players
            ? this.room.players.map((p) => ({ ...p, cls: 'player' + (p.isMe ? ' me' : '') }))
            : [];
    }
    get playerCount() { return this.players.length; }
    get isHost() { return !!(this.room && this.room.isHost); }
    get lobbyInfo() {
        return this.room ? `${this.room.topic === 'Any' ? 'Mixed topics' : this.room.topic}, ${this.room.level}, ${this.room.total} questions, ${this.room.secondsPerQuestion}s each` : '';
    }
    get startLabel() { return this.starting ? 'Starting…' : 'Start the game'; }
    get joinPlaceholder() { return this.me ? this.me.displayName : 'Your nickname'; }

    onJoinNick(e) { this.joinNick = e.target.value; }
    onJoinKey(e) { if (e.key === 'Enter') this.join(); }

    async join() {
        this.error = '';
        this.busy = true;
        try {
            const res = await joinRoom({
                sessionToken: this.sessionToken,
                code: this.code,
                nickname: this.joinNick.trim() || null,
                playerToken: null
            });
            this.joinedToken = res.playerToken;
            this.fire('playerready', { code: res.code, playerToken: res.playerToken });
            this.startPolling();
        } catch (e) {
            this.error = errMsg(e);
        } finally {
            this.busy = false;
        }
    }

    startPolling() {
        this.stopPolling();
        this.refresh();
        this.pollTimer = setInterval(() => this.refresh(), 2000);
    }
    stopPolling() {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
    }
    async refresh() {
        if (this.inflight || !this.activeToken) return;
        this.inflight = true;
        try {
            const s = await getRoomState({ code: this.code, playerToken: this.activeToken });
            this.room = s;
            this.error = '';
            if (s.status !== 'Lobby') {
                this.stopPolling();
                this.fire('statuschange', { status: s.status });
            }
        } catch (e) {
            const m = errMsg(e);
            if (m === 'REJOIN_REQUIRED') {
                this.stopPolling();
                this.joinedToken = null;
                this.room = null;
                this.fire('playerlost', {});
            } else {
                this.error = m;
            }
        } finally {
            this.inflight = false;
        }
    }

    async start() {
        this.starting = true;
        try {
            await startGame({ code: this.code, playerToken: this.activeToken });
            await this.refresh();
        } catch (e) {
            this.error = errMsg(e);
        } finally {
            this.starting = false;
        }
    }

    shareLink() {
        return `${window.location.origin}${window.location.pathname}?code=${this.code}`;
    }
    async copy(text, okMessage) {
        try {
            await navigator.clipboard.writeText(text);
            this.fire('toast', { message: okMessage, variant: 'good' });
        } catch (e) {
            this.fire('toast', { message: 'Copy is blocked here. Select the code and copy it by hand.', variant: 'error' });
        }
    }
    copyCode() { this.copy(this.code, 'Room code copied.'); }
    copyLink() { this.copy(this.shareLink(), 'Invite link copied.'); }
    leave() { this.fire('navigate', { page: 'home' }); }

    fire(name, detail) {
        this.dispatchEvent(new CustomEvent(name, { detail }));
    }
}