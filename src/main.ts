import './style.css';
import { Game } from './game';
import { sound } from './audio';
import type { WeaponType } from './types';

window.addEventListener('DOMContentLoaded', () => {
  const canvas = document.getElementById('game-canvas') as HTMLCanvasElement;
  const loadingScreen = document.getElementById('loading-screen') as HTMLDivElement;
  const startBtn = document.getElementById('start-btn') as HTMLButtonElement;
  const hud = document.getElementById('hud') as HTMLDivElement;

  // Top-Left Corner HUD elements
  const healthBarFill = document.getElementById('health-bar-fill') as HTMLDivElement;
  const healthBarText = document.getElementById('health-bar-text') as HTMLSpanElement;
  const currentWeaponBadge = document.getElementById('current-weapon-badge') as HTMLSpanElement;
  const currentAmmoBadge = document.getElementById('current-ammo-badge') as HTMLSpanElement;

  // Top-Center Wave
  const waveVal = document.getElementById('wave-val') as HTMLSpanElement;

  // Top-Right Corner HUD elements
  const killCount = document.getElementById('kill-count') as HTMLSpanElement;
  const highScoreVal = document.getElementById('high-score') as HTMLSpanElement;
  const scoreVal = document.getElementById('score-val') as HTMLSpanElement;

  // Weapon Switcher On-Screen Buttons
  const weaponSwitcherBar = document.getElementById('weapon-switcher-bar') as HTMLDivElement;
  const btnPistol = document.getElementById('btn-weapon-pistol') as HTMLButtonElement;
  const btnShotgun = document.getElementById('btn-weapon-shotgun') as HTMLButtonElement;
  const btnRifle = document.getElementById('btn-weapon-rifle') as HTMLButtonElement;
  const btnAmmoShotgun = document.getElementById('btn-ammo-shotgun') as HTMLSpanElement;
  const btnAmmoRifle = document.getElementById('btn-ammo-rifle') as HTMLSpanElement;

  // Game Over Modal
  const gameOverScreen = document.getElementById('game-over-screen') as HTMLDivElement;
  const finalScore = document.getElementById('final-score') as HTMLSpanElement;
  const finalKills = document.getElementById('final-kills') as HTMLSpanElement;
  const finalWave = document.getElementById('final-wave') as HTMLSpanElement;
  const finalHighScore = document.getElementById('final-highscore') as HTMLSpanElement;
  const restartBtn = document.getElementById('restart-btn') as HTMLButtonElement;

  // Audio Toggle
  const soundBtn = document.getElementById('sound-btn') as HTMLButtonElement;
  const soundIconOn = document.getElementById('sound-icon-on') as unknown as SVGElement;
  const soundIconOff = document.getElementById('sound-icon-off') as unknown as SVGElement;

  soundBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    const isMuted = sound.toggleMute();
    if (isMuted) {
      soundIconOn.classList.add('hidden');
      soundIconOff.classList.remove('hidden');
    } else {
      soundIconOn.classList.remove('hidden');
      soundIconOff.classList.add('hidden');
    }
  });

  // Initialize Game
  const game = new Game(canvas, (state) => {
    // 1. Top-Left: Player Health Bar
    const hpPercent = Math.max(0, Math.min(100, (state.health / state.maxHealth) * 100));
    healthBarFill.style.width = `${hpPercent}%`;
    healthBarText.textContent = `${Math.ceil(state.health)} / ${state.maxHealth}`;

    if (hpPercent < 30) {
      healthBarFill.style.background = 'linear-gradient(90deg, #b91c1c 0%, #ef4444 100%)';
    } else if (hpPercent < 60) {
      healthBarFill.style.background = 'linear-gradient(90deg, #d97706 0%, #f59e0b 100%)';
    } else {
      healthBarFill.style.background = 'linear-gradient(90deg, #15803d 0%, #22c55e 100%)';
    }

    // 2. Top-Left: Current Weapon & Ammo Count
    currentWeaponBadge.textContent = state.currentWeapon.name;
    currentAmmoBadge.textContent = `AMMO: ${state.ammoDisplay}`;

    // 3. Top-Center: Sector & Wave
    const sectorVal = document.getElementById('sector-val');
    if (sectorVal) {
      sectorVal.textContent = state.roomName;
    }
    waveVal.textContent = `WAVE ${state.wave}`;

    // 4. Top-Right: Killed Enemy Count, High Score, Score
    killCount.textContent = state.kills.toLocaleString();
    highScoreVal.textContent = game.highScore.toLocaleString();
    scoreVal.textContent = state.score.toLocaleString();

    // 5. Update On-Screen Weapon Switcher Buttons
    btnAmmoShotgun.textContent = `${state.shotgunAmmo}`;
    btnAmmoRifle.textContent = `${state.rifleAmmo}`;

    // Highlight active weapon button
    btnPistol.classList.toggle('active', state.currentWeaponType === 'pistol');
    btnShotgun.classList.toggle('active', state.currentWeaponType === 'shotgun');
    btnRifle.classList.toggle('active', state.currentWeaponType === 'rifle');

    // 6. Game Over Modal
    if (state.isGameOver) {
      finalScore.textContent = state.score.toLocaleString();
      finalKills.textContent = state.kills.toLocaleString();
      finalWave.textContent = `WAVE ${state.wave}`;
      finalHighScore.textContent = game.highScore.toLocaleString();
      gameOverScreen.classList.remove('hidden');
      weaponSwitcherBar.classList.add('hidden');
    } else {
      gameOverScreen.classList.add('hidden');
    }
  });

  // Weapon Switch Button Listeners (Mobile touch & click)
  const setupWeaponButton = (btn: HTMLButtonElement, weapon: WeaponType) => {
    const handleSwitch = (e: Event) => {
      e.stopPropagation();
      e.preventDefault();
      game.switchWeapon(weapon);
    };
    btn.addEventListener('click', handleSwitch);
    btn.addEventListener('pointerdown', handleSwitch);
  };

  setupWeaponButton(btnPistol, 'pistol');
  setupWeaponButton(btnShotgun, 'shotgun');
  setupWeaponButton(btnRifle, 'rifle');

  // Start game sequence from loading screen
  const startGame = () => {
    if (game.isRunning) return;

    const eyes = document.querySelectorAll<HTMLElement>('.eye');
    eyes.forEach((eye) => {
      eye.style.filter = 'brightness(2.2)';
      eye.style.boxShadow = '0 0 40px #ff0000, 0 0 100px #ff0000, 0 0 15px #ffffff';
    });

    setTimeout(() => {
      loadingScreen.classList.add('fade-out');
      hud.classList.remove('hidden');
      weaponSwitcherBar.classList.remove('hidden');
      game.start();
    }, 250);
  };

  startBtn.addEventListener('click', startGame);
  loadingScreen.addEventListener('click', (e) => {
    if ((e.target as HTMLElement).tagName !== 'BUTTON') {
      startGame();
    }
  });

  restartBtn.addEventListener('click', () => {
    gameOverScreen.classList.add('hidden');
    weaponSwitcherBar.classList.remove('hidden');
    game.restart();
  });
});
