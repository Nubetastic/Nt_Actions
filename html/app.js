const root = document.getElementById('fine-tune');
const editorTitle = document.getElementById('editor-title');
const pointCoords = document.getElementById('point-coords');
const pointCoordsOption = document.getElementById('point-coords-option');
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
const navFooterActions = document.getElementById('nav-footer-actions');
const navPanel = navigation.querySelector('.nav-panel');
const scaleStorageKey = 'nt_actions_ui_scale';
const defaultUiScale = 1;
const absoluteScaleMin = 0.5;
const absoluteScaleMax = 2;
const scaleStep = 0.05;
let selectedNavIndex = 0;
let rotationMultiplier = 200;
let selectedUiScale = defaultUiScale;

const updateStepLabel = () => {
    const movement = Number(movementStep.value);
    movementValue.textContent = `${movement.toFixed(3)} m / ${(movement * rotationMultiplier).toFixed(1)}\u00B0`;
};

const send = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
});

const roundScaleDown = (value) => Math.floor((value + Number.EPSILON) / scaleStep) * scaleStep;

const getStoredScale = () => {
    const storedScale = Number(localStorage.getItem(scaleStorageKey));
    return Number.isFinite(storedScale) && storedScale > 0 ? storedScale : null;
};

const applyNavScale = (requestedScale, persist = true) => {
    const maximum = Number(navScale.max) || absoluteScaleMax;
    selectedUiScale = Math.max(absoluteScaleMin, Math.min(maximum, Number(requestedScale) || defaultUiScale));
    selectedUiScale = Math.round(selectedUiScale / scaleStep) * scaleStep;
    document.documentElement.style.setProperty('--nav-scale', selectedUiScale);
    navScale.value = selectedUiScale;
    navScaleValue.textContent = `${Math.round(selectedUiScale * 100)}%`;
    if (persist) localStorage.setItem(scaleStorageKey, selectedUiScale.toFixed(2));
};

const updateViewportScaleMaximum = (persist = true) => {
    if (!navigation.classList.contains('visible')) return;
    const widthScale = (window.innerWidth * 0.94) / navPanel.offsetWidth;
    const heightScale = (window.innerHeight * 0.94) / navPanel.offsetHeight;
    const viewportMax = Math.min(absoluteScaleMax, widthScale, heightScale);
    const maxScale = Math.max(absoluteScaleMin, roundScaleDown(viewportMax));
    navScale.max = maxScale.toFixed(2);
    const previousScale = selectedUiScale;
    applyNavScale(selectedUiScale, persist);
    if (selectedUiScale !== previousScale) send('navScale', { scale: selectedUiScale });
};

window.addEventListener('message', ({ data }) => {
    if (data.action === 'navOpen') {
        navTitle.textContent = data.title || 'Menu';
        const configuredMin = Number(data.scaleMin);
        const configuredMax = Number(data.scaleMax);
        navScale.min = Number.isFinite(configuredMin) ? Math.max(absoluteScaleMin, configuredMin) : absoluteScaleMin;
        navScale.max = Number.isFinite(configuredMax) ? Math.min(absoluteScaleMax, configuredMax) : absoluteScaleMax;
        navScale.step = scaleStep;
        const storedScale = getStoredScale();
        selectedUiScale = storedScale !== null ? storedScale : (Number(data.scale) || defaultUiScale);
        navScaleControl.classList.toggle('visible', data.showScale === true);
        navOptions.innerHTML = '';
        (data.options || []).forEach((option, index) => {
            const row = document.createElement('div');
            row.className = 'nav-option-row';
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
            row.appendChild(button);
            if (option.deletable === true) {
                const deleteButton = document.createElement('button');
                deleteButton.type = 'button';
                deleteButton.className = 'nav-delete';
                deleteButton.textContent = '\u2212';
                deleteButton.title = `Hide ${option.label}`;
                deleteButton.setAttribute('aria-label', `Delete ${option.label}`);
                deleteButton.addEventListener('click', (event) => {
                    event.stopPropagation();
                    send('navDelete', { index: index + 1 });
                });
                row.appendChild(deleteButton);
            }
            if (option.restorable === true) {
                const restoreButton = document.createElement('button');
                restoreButton.type = 'button';
                restoreButton.className = 'nav-restore';
                restoreButton.textContent = '+';
                restoreButton.title = `Restore ${option.label}`;
                restoreButton.setAttribute('aria-label', `Restore ${option.label}`);
                restoreButton.addEventListener('click', (event) => {
                    event.stopPropagation();
                    send('navRestore', { index: index + 1 });
                });
                row.appendChild(restoreButton);
            }
            navOptions.appendChild(row);
        });
        navFooterActions.innerHTML = '';
        (data.footerActions || []).forEach((action, index) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.textContent = action.label;
            button.disabled = action.disabled === true;
            button.addEventListener('click', () => send('navFooter', { index: index + 1 }));
            navFooterActions.appendChild(button);
        });
        navFooterActions.style.display = (data.footerActions || []).length ? 'flex' : 'none';
        navBack.disabled = !data.canGoBack;
        navBack.style.display = data.canGoBack ? 'block' : 'none';
        selectedNavIndex = 0;
        navigation.classList.add('visible');
        navigation.setAttribute('aria-hidden', 'false');
        applyNavScale(selectedUiScale);
        requestAnimationFrame(() => updateViewportScaleMaximum());
        selectNavOption(0);
    }
    if (data.action === 'navClose') {
        navigation.classList.remove('visible');
        navigation.setAttribute('aria-hidden', 'true');
    }
    if (data.action === 'open') {
        editorTitle.textContent = data.editorTitle || 'Fine tune position';
        pointCoords.checked = false;
        pointCoords.disabled = data.pointAvailable !== true;
        pointCoordsOption.classList.toggle('unavailable', pointCoords.disabled);
        const editorScale = Number(data.scale) || getStoredScale() || defaultUiScale;
        document.documentElement.style.setProperty('--editor-scale', editorScale);
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
    applyNavScale(Number(navScale.value));
    send('navScale', { scale: selectedUiScale });
});

window.addEventListener('resize', () => updateViewportScaleMaximum());

document.querySelectorAll('[data-direction]').forEach((button) => {
    button.addEventListener('click', async () => {
        pointCoords.checked = false;
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
        pointCoords.checked = false;
        const response = await send('rotate', {
            direction: button.dataset.rotation,
            step: Number(movementStep.value),
        });
        const result = await response.json();
        if (result.offset) headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
    });
});

pointCoords.addEventListener('change', async () => {
    if (!pointCoords.checked || pointCoords.disabled) return;
    const response = await send('pointCoords');
    const result = await response.json();
    if (!result.ok) {
        pointCoords.checked = false;
        pointCoords.disabled = true;
        pointCoordsOption.classList.add('unavailable');
        return;
    }
    if (result.offset) headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
});

window.addEventListener('mousedown', (event) => {
    if (event.button !== 2 || !root.classList.contains('visible')) return;
    event.preventDefault();
    send('cameraLook');
});

window.addEventListener('contextmenu', (event) => event.preventDefault());

document.getElementById('confirm').addEventListener('click', () => {
    send('confirm');
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
