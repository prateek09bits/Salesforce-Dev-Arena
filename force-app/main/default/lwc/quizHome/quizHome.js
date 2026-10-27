import { LightningElement, api } from 'lwc';
import getLeaderboard from '@salesforce/apex/AstroProfileController.getLeaderboard';

const TOPICS = ['Apex', 'LWC', 'SOQL', 'Flows', 'Integration', 'Security', 'Data Modeling', 'Admin'];
// Hand-placed star positions (viewBox 0 0 420 360) for the topic constellation
const STARS = [
    [60, 250], [128, 150], [215, 205], [262, 92], [345, 160], [330, 268], [200, 300], [92, 62]
];
const LINKS = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [2, 6], [1, 7], [6, 5]];

export default class QuizHome extends LightningElement {
    @api me;
    leaders = [];
    loaded = false;
    joinCode = '';
    joinError = '';

    connectedCallback() {
        getLeaderboard({ limitCount: 5 })
            .then((rows) => { this.leaders = rows; })
            .catch(() => { this.leaders = []; })
            .finally(() => { this.loaded = true; });
    }

    get stars() {
        return TOPICS.map((name, i) => ({
            name,
            x: STARS[i][0],
            y: STARS[i][1],
            tx: STARS[i][0] + (STARS[i][0] > 210 ? -12 : 12),
            ty: STARS[i][1] - 12,
            anchor: STARS[i][0] > 210 ? 'end' : 'start'
        }));
    }
    get lines() {
        return LINKS.map(([a, b], i) => ({
            id: 'l' + i, x1: STARS[a][0], y1: STARS[a][1], x2: STARS[b][0], y2: STARS[b][1]
        }));
    }
    get rows() {
        return this.leaders.map((r) => ({ ...r, key: r.username, scoreLabel: r.totalScore.toLocaleString() }));
    }
    get hasLeaders() {
        return this.leaders.length > 0;
    }
    get showEmpty() {
        return this.loaded && !this.hasLeaders;
    }

    go(page, state) {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { page, state } }));
    }
    playSolo() { this.go('play', { mode: 'solo' }); }
    createRoom() { this.go('play', { mode: 'room' }); }
    onCode(event) {
        this.joinCode = event.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
        this.joinError = '';
    }
    onCodeKey(event) {
        if (event.key === 'Enter') this.joinRoom();
    }
    joinRoom() {
        if (this.joinCode.length < 4) {
            this.joinError = 'Enter the room code your host shared.';
            return;
        }
        this.go('room', { code: this.joinCode });
    }
    openProfile(event) {
        this.go('profile', { u: event.currentTarget.dataset.u });
    }
    openBoard() {
        this.go('profile', { tab: 'leaders' });
    }
}