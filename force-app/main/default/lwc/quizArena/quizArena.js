import { LightningElement, api } from 'lwc';
import getRoomState from '@salesforce/apex/AstroGameController.getRoomState';
import submitAnswer from '@salesforce/apex/AstroGameController.submitAnswer';

const POLL_MS = 2000;
const REVEAL_MS = 6000;
const errMsg = (e) => (e && e.body && e.body.message) || (e && e.message) || 'Something went wrong.';
const keyBadge = (k) => (k.length > 1 ? k.charAt(0) : k);

/**
 * Live game. The server owns the clock: every poll returns the current phase and when it ends (server time).
 * The client keeps a smooth countdown from the server offset and re-polls the moment a phase runs out.
 */
export default class QuizArena extends LightningElement {
    @api code;
    @api me;
    @api sessionToken;
    @api playerToken;

    s; // latest room state
    selected = [];
    remainingMs = 0;
    busy = false;
    error = '';
    showReview = false;

    offset = 0;
    lastIndex = -1;
    stopped = false;
    inflight = false;
    kickedFor = 0;
    pollTimer;
    tickTimer;

    connectedCallback() {
        this.loop();
        this.tickTimer = setInterval(() => this.onTick(), 200);
    }
    disconnectedCallback() {
        this.stopped = true;
        clearTimeout(this.pollTimer);
        clearInterval(this.tickTimer);
    }

    // ------------------------------------------------------------ polling
    async loop() {
        await this.refresh();
        if (this.stopped || (this.s && this.s.phase === 'FINISHED')) return;
        clearTimeout(this.pollTimer);
        this.pollTimer = setTimeout(() => this.loop(), this.nextDelay());
    }
    nextDelay() {
        if (!this.s || !this.s.phaseEndsAt) return POLL_MS;
        const ms = this.s.phaseEndsAt - (Date.now() + this.offset);
        return ms > 0 && ms < POLL_MS ? ms + 150 : POLL_MS;
    }
    async refresh() {
        this.inflight = true;
        try {
            const s = await getRoomState({ code: this.code, playerToken: this.playerToken });
            this.offset = s.serverNow - Date.now();
            if (s.index !== this.lastIndex) {
                this.lastIndex = s.index;
                this.selected = [];
            }
            this.s = s;
            if (s.myAnswer) this.selected = s.myAnswer.split(',');
            this.error = '';
            this.updateRemaining();
        } catch (e) {
            if (errMsg(e) === 'REJOIN_REQUIRED') {
                this.stopped = true;
                this.dispatchEvent(new CustomEvent('playerlost'));
            } else {
                this.error = 'Connection hiccup. Retrying…';
            }
        } finally {
            this.inflight = false;
        }
    }
    updateRemaining() {
        this.remainingMs = this.s && this.s.phaseEndsAt ? Math.max(0, this.s.phaseEndsAt - (Date.now() + this.offset)) : 0;
    }
    onTick() {
        if (!this.s || !this.s.phaseEndsAt) return;
        this.updateRemaining();
        if (this.remainingMs <= 0 && this.kickedFor !== this.s.phaseEndsAt && !this.inflight && !this.stopped) {
            this.kickedFor = this.s.phaseEndsAt;
            clearTimeout(this.pollTimer);
            this.loop();
        }
    }

    // ------------------------------------------------------------ answering
    get locked() {
        return this.isReveal || this.busy || !!(this.s && this.s.myAnswer) || this.remainingMs <= 0;
    }
    pickOption(event) {
        if (this.locked) return;
        const key = event.currentTarget.dataset.key;
        if (this.s.question.multi) {
            this.selected = this.selected.includes(key) ? this.selected.filter((k) => k !== key) : [...this.selected, key];
            return;
        }
        this.selected = [key];
        this.submit();
    }
    async submit() {
        if (!this.selected.length || this.busy || this.locked) return;
        this.busy = true;
        try {
            await submitAnswer({
                code: this.code,
                playerToken: this.playerToken,
                questionIndex: this.s.index,
                answer: [...this.selected].sort().join(',')
            });
            await this.refresh();
        } catch (e) {
            this.error = errMsg(e);
            this.selected = [];
        } finally {
            this.busy = false;
        }
    }

    // ------------------------------------------------------------ phase flags
    get isStarting() { return this.s.phase === 'STARTING'; }
    get isPlaying() { return this.s.phase === 'QUESTION' || this.s.phase === 'REVEAL'; }
    get isQuestion() { return this.s.phase === 'QUESTION'; }
    get isReveal() { return !!this.s && this.s.phase === 'REVEAL'; }
    get isFinished() { return this.s.phase === 'FINISHED'; }
    get isMulti() { return !!(this.s.question && this.s.question.multi); }
    get hasCode() { return !!(this.s.question && this.s.question.code); }
    get showBoard() { return this.s.players.length > 1; }
    get secondsLeft() { return Math.ceil(this.remainingMs / 1000); }
    get questionNumber() { return this.s.index + 1; }
    get canLockIn() { return this.isQuestion && this.isMulti && !this.s.myAnswer && this.selected.length > 0 && !this.busy; }
    get answeredWaiting() { return this.isQuestion && !!this.s.myAnswer; }
    get hint() {
        return this.isMulti ? 'Select every correct answer, then lock in.' : 'Pick one. Faster correct answers score more.';
    }

    get ringStyle() {
        const total = this.isQuestion ? this.s.secondsPerQuestion * 1000 : REVEAL_MS;
        const pct = Math.max(0, Math.min(1, this.remainingMs / total));
        const color = !this.isQuestion ? 'var(--border-strong)' : pct < 0.25 ? 'var(--bad)' : 'var(--accent)';
        return `background: conic-gradient(${color} ${pct * 360}deg, rgba(255,238,200,.1) 0deg);`;
    }

    get options() {
        const q = this.s.question;
        const correct = this.isReveal && this.s.correctAnswer ? this.s.correctAnswer.split(',') : [];
        return q.options.map((o) => {
            const picked = this.selected.includes(o.key);
            let cls = 'opt';
            if (this.isReveal) cls += correct.includes(o.key) ? ' ok' : picked ? ' bad' : ' dim';
            else if (picked) cls += ' sel';
            return { key: o.key, label: o.label, badge: keyBadge(o.key), cls, disabled: this.locked };
        });
    }

    get revealCls() { return 'reveal ' + (this.s.myIsCorrect ? 'good' : 'miss'); }
    get revealTitle() {
        if (!this.s.myAnswer) return 'No answer in time';
        return this.s.myIsCorrect ? 'Correct' : 'Not quite';
    }
    get pointsLabel() { return this.s.myIsCorrect ? '+' + this.s.myPoints : '+0'; }

    // ------------------------------------------------------------ scoreboard + results
    get board() {
        return this.s.players.map((p, i) => ({
            ...p,
            rank: i + 1,
            cls: 'prow' + (p.isMe ? ' me' : ''),
            state: this.isQuestion ? (p.answered ? 'answered' : 'thinking') : ''
        }));
    }
    get myRank() {
        const i = this.s.players.findIndex((p) => p.isMe);
        return i < 0 ? 0 : i + 1;
    }
    get myScore() {
        const me = this.s.players.find((p) => p.isMe);
        return me ? me.score.toLocaleString() : '0';
    }
    get correctCount() { return this.s.reviews ? this.s.reviews.filter((r) => r.isCorrect).length : 0; }
    get accuracy() { return this.s.total ? Math.round((100 * this.correctCount) / this.s.total) : 0; }
    get resultTitle() {
        if (this.s.isSolo) return 'Round complete';
        return this.myRank === 1 ? 'You won the room' : 'Game over';
    }
    get resultSub() {
        return this.s.isSolo ? 'Here is how you did.' : `You finished ${this.ordinal(this.myRank)} of ${this.s.players.length}.`;
    }
    get ranking() {
        return this.s.players.map((p, i) => ({ ...p, rank: i + 1, cls: 'rrow' + (p.isMe ? ' me' : ''), scoreLabel: p.score.toLocaleString() }));
    }
    get guestNudge() { return !this.me; }
    get reviewLabel() { return this.showReview ? 'Hide answer review' : 'Review answers'; }
    get reviews() {
        return (this.s.reviews || []).map((r) => {
            const correct = r.correct.split(',');
            const mine = r.myAnswer ? r.myAnswer.split(',') : [];
            return {
                ...r,
                num: r.index + 1,
                cls: 'rev ' + (r.isCorrect ? 'good' : 'miss'),
                verdict: r.myAnswer ? (r.isCorrect ? 'Correct, +' + r.points : 'Incorrect') : 'Unanswered',
                hasCode: !!r.code,
                options: r.options.map((o) => ({
                    key: o.key,
                    label: o.label,
                    badge: keyBadge(o.key),
                    cls: 'ro' + (correct.includes(o.key) ? ' ok' : mine.includes(o.key) ? ' bad' : ''),
                    tag: correct.includes(o.key) ? 'Correct answer' : mine.includes(o.key) ? 'Your answer' : ''
                }))
            };
        });
    }
    ordinal(n) {
        const v = n % 100;
        const suffix = ['th', 'st', 'nd', 'rd'][(v - 20) % 10] || ['th', 'st', 'nd', 'rd'][v] || 'th';
        return n + suffix;
    }

    toggleReview() { this.showReview = !this.showReview; }
    playAgain() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'play', state: { mode: this.s.isSolo ? 'solo' : 'room' } } }));
    }
    goHome() { this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'home' } })); }
    goLogin() { this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'login' } })); }
}