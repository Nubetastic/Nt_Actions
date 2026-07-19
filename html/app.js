const root = document.getElementById('fine-tune');
const saveOffset = document.getElementById('save-offset');
const movementStep = document.getElementById('movement-step');
const movementValue = document.getElementById('movement-value');
const headingValue = document.getElementById('heading-value');
const cameraZoom = document.getElementById('camera-zoom');
const cameraZoomValue = document.getElementById('camera-zoom-value');
const navigation = document.getElementById('navigation');
const navTitle = document.getElementById('nav-title');
const navOptions = document.getElementById('nav-options');
const navDescription = document.getElementById('nav-description');
const navScaleControl = document.getElementById('nav-scale-control');
const navScale = document.getElementById('nav-scale');
const navScaleValue = document.getElementById('nav-scale-value');
const navBack = document.getElementById('nav-back');
let selectedNavIndex = 0;
let rotationMultiplier = 200;

const updateStepLabel = () => {
    const movement = Number(movementStep.value);
    movementValue.textContent = `${movement.toFixed(3)} m / ${(movement * rotationMultiplier).toFixed(1)}\u00B0`;
};

const send = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
});

window.addEventListener('message', ({ data }) => {
    if (data.action === 'navOpen') {
        navTitle.textContent = data.title || 'Menu';
        const scale = Number(data.scale) || 1;
        document.documentElement.style.setProperty('--nav-scale', scale);
        navScale.min = data.scaleMin !== undefined ? data.scaleMin : 0.75;
        navScale.max = data.scaleMax !== undefined ? data.scaleMax : 1.25;
        navScale.step = data.scaleStep !== undefined ? data.scaleStep : 0.05;
        navScale.value = scale;
        navScaleValue.textContent = `${scale.toFixed(2)}x`;
        navScaleControl.classList.toggle('visible', data.showScale === true);
        navOptions.innerHTML = '';
        (data.options || []).forEach((option, index) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'nav-option';
            button.disabled = option.disabled === true;
            button.dataset.index = index + 1;
            button.dataset.description = option.description || '';
            button.textContent = option.label;
            button.addEventListener('mouseenter', () => {
                const enabledButtons = Array.from(navOptions.querySelectorAll('.nav-option:not(:disabled)'));
                selectNavOption(enabledButtons.indexOf(button));
            });
            button.addEventListener('click', () => {
                const enabledButtons = Array.from(navOptions.querySelectorAll('.nav-option:not(:disabled)'));
                selectNavOption(enabledButtons.indexOf(button));
                send('navSelect', { index: index + 1 });
            });
            navOptions.appendChild(button);
        });
        navBack.disabled = !data.canGoBack;
        selectedNavIndex = 0;
        navigation.classList.add('visible');
        navigation.setAttribute('aria-hidden', 'false');
        selectNavOption(0);
    }
    if (data.action === 'navClose') {
        navigation.classList.remove('visible');
        navigation.setAttribute('aria-hidden', 'true');
    }
    if (data.action === 'open') {
        saveOffset.checked = true;
        movementStep.min = data.stepMin !== undefined ? data.stepMin : 0.005;
        movementStep.max = data.stepMax !== undefined ? data.stepMax : 0.25;
        movementStep.step = data.sliderStep !== undefined ? data.sliderStep : 0.005;
        movementStep.value = data.step !== undefined ? data.step : 0.025;
        rotationMultiplier = data.rotationMultiplier !== undefined ? data.rotationMultiplier : 200;
        updateStepLabel();
        cameraZoom.min = data.cameraZoomMin !== undefined ? data.cameraZoomMin : 0.75;
        cameraZoom.max = data.cameraZoomMax !== undefined ? data.cameraZoomMax : 8;
        cameraZoom.step = data.cameraZoomStep !== undefined ? data.cameraZoomStep : 0.25;
        cameraZoom.value = data.cameraDistance !== undefined ? data.cameraDistance : 3;
        cameraZoomValue.textContent = `${Number(cameraZoom.value).toFixed(2)} m`;
        const heading = data.offset && data.offset.heading !== undefined ? data.offset.heading : 0;
        headingValue.textContent = `${Math.round(heading)}\u00B0`;
        root.classList.add('visible');
        root.setAttribute('aria-hidden', 'false');
    }
    if (data.action === 'close') {
        root.classList.remove('visible');
        root.setAttribute('aria-hidden', 'true');
    }
});

const selectNavOption = (requestedIndex) => {
    const buttons = Array.from(navOptions.querySelectorAll('.nav-option:not(:disabled)'));
    if (!buttons.length) {
        navDescription.textContent = '';
        navDescription.classList.remove('visible');
        return;
    }
    selectedNavIndex = (requestedIndex + buttons.length) % buttons.length;
    buttons.forEach((button, index) => button.classList.toggle('selected', index === selectedNavIndex));
    const selectedButton = buttons[selectedNavIndex];
    const description = selectedButton.dataset.description || '';
    navDescription.textContent = description;
    navDescription.classList.toggle('visible', description.length > 0);
    selectedButton.scrollIntoView({ block: 'nearest' });
};

navBack.addEventListener('click', () => send('navBack'));
document.getElementById('nav-close').addEventListener('click', () => send('navClose'));

navScale.addEventListener('input', () => {
    const scale = Number(navScale.value);
    document.documentElement.style.setProperty('--nav-scale', scale);
    navScaleValue.textContent = `${scale.toFixed(2)}x`;
    send('navScale', { scale });
});

document.querySelectorAll('[data-direction]').forEach((button) => {
    button.addEventListener('click', async () => {
        const response = await send('move', {
            direction: button.dataset.direction,
            step: Number(movementStep.value),
        });
        const result = await response.json();
        if (result.offset) headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
    });
});

movementStep.addEventListener('input', () => {
    updateStepLabel();
});

cameraZoom.addEventListener('input', () => {
    cameraZoomValue.textContent = `${Number(cameraZoom.value).toFixed(2)} m`;
    send('cameraZoom', { distance: Number(cameraZoom.value) });
});

document.querySelectorAll('[data-rotation]').forEach((button) => {
    button.addEventListener('click', async () => {
        const response = await send('rotate', {
            direction: button.dataset.rotation,
            step: Number(movementStep.value),
        });
        const result = await response.json();
        if (result.offset) headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
    });
});

window.addEventListener('mousedown', (event) => {
    if (event.button !== 2 || !root.classList.contains('visible')) return;
    event.preventDefault();
    send('cameraLook');
});

window.addEventListener('contextmenu', (event) => event.preventDefault());

document.getElementById('confirm').addEventListener('click', () => {
    send('confirm', { save: saveOffset.checked });
});

document.getElementById('cancel').addEventListener('click', () => send('cancel'));

window.addEventListener('keydown', (event) => {
    if (navigation.classList.contains('visible')) {
        if (event.key === 'ArrowDown') selectNavOption(selectedNavIndex + 1);
        if (event.key === 'ArrowUp') selectNavOption(selectedNavIndex - 1);
        if (event.key === 'Enter') {
            const buttons = navOptions.querySelectorAll('.nav-option:not(:disabled)');
            if (buttons[selectedNavIndex]) buttons[selectedNavIndex].click();
        }
        if (event.key === 'Backspace') send('navBack');
        if (event.key === 'Escape') send('navClose');
        if (event.key.toLowerCase() === 'l') send('navClose');
        return;
    }
    if (event.key === 'Escape' && root.classList.contains('visible')) send('cancel');
});
