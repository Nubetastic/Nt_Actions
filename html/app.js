const root = document.getElementById('fine-tune');
const editorTitle = document.getElementById('editor-title');
const editorCoordList = document.getElementById('editor-coord-list');
const separatePoint = document.getElementById('separate-point');
const separatePointOption = document.getElementById('separate-point-option');
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
const navMod = document.getElementById('nav-mod');
const navFooterActions = document.getElementById('nav-footer-actions');
const navReviewCamera = document.getElementById('nav-review-camera');
const navReviewZoom = document.getElementById('nav-review-zoom');
const navReviewZoomValue = document.getElementById('nav-review-zoom-value');

const renderNavFooterActions = (actions = []) => {
    navFooterActions.innerHTML = '';
    actions.forEach((action, index) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = action.label;
        button.disabled = action.disabled === true;
        button.classList.toggle('danger', action.danger === true);
        button.addEventListener('click', () => send('navFooter', { index: index + 1 }));
        navFooterActions.appendChild(button);
    });
    navFooterActions.style.display = actions.length ? 'flex' : 'none';
};
const navCoordinates = document.getElementById('nav-coordinates');
const navCoordinateList = document.getElementById('nav-coordinate-list');
const navLayout = navigation.querySelector('.nav-layout');
const scaleStorageKey = 'nt_actions_ui_scale';
const defaultUiScale = 1;
const absoluteScaleMin = 0.5;
const absoluteScaleMax = 2;
const scaleStep = 0.05;
let selectedNavIndex = 0;
let rotationMultiplier = 200;
let selectedUiScale = defaultUiScale;
let editorCoordinates = [];
let editorPoints = [];

const updateStepLabel = () => {
    const movement = Number(movementStep.value);
    movementValue.textContent = `${movement.toFixed(3)} m / ${(movement * rotationMultiplier).toFixed(1)}\u00B0`;
};

const send = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
});

const renderEditorCoordinates = (requestedKey) => {
    const selectedKey = requestedKey || editorCoordList.querySelector('.editor-coord.selected')?.dataset.key;
    editorCoordList.innerHTML = '';
    const addButton = (label, payload, key) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'editor-coord';
        button.dataset.key = key;
        button.textContent = label;
        button.classList.toggle('selected', key === selectedKey);
        button.addEventListener('click', async () => {
            const response = await send('selectEditorCoord', payload);
            const result = await response.json();
            if (!result.ok) return;
            editorCoordList.querySelectorAll('.editor-coord').forEach((item) => item.classList.remove('selected'));
            button.classList.add('selected');
            if (result.offset) headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
        });
        editorCoordList.appendChild(button);
    };
    editorCoordinates.forEach((_, index) => addButton(String(index + 1), { coordNumber: index + 1 }, `C${index + 1}`));
    editorPoints.forEach((_, index) => addButton(`P${index + 1}`, { pointIndex: index + 1 }, `P${index + 1}`));
};

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
    const widthScale = (window.innerWidth * 0.94) / navLayout.offsetWidth;
    const heightScale = (window.innerHeight * 0.94) / navLayout.offsetHeight;
    const viewportMax = Math.min(absoluteScaleMax, widthScale, heightScale);
    const maxScale = Math.max(absoluteScaleMin, roundScaleDown(viewportMax));
    navScale.max = maxScale.toFixed(2);
    const previousScale = selectedUiScale;
    applyNavScale(selectedUiScale, persist);
    if (selectedUiScale !== previousScale) send('navScale', { scale: selectedUiScale });
};

window.addEventListener('message', ({ data }) => {
    if (data.action === 'navFooterUpdate') {
        renderNavFooterActions(data.footerActions || []);
        return;
    }
    if (data.action === 'navOpen') {
        const preservedOptionsScroll = data.preserveScroll === true ? navOptions.scrollTop : 0;
        navTitle.textContent = data.title || 'Menu';
        const configuredMin = Number(data.scaleMin);
        const configuredMax = Number(data.scaleMax);
        navScale.min = Number.isFinite(configuredMin) ? Math.max(absoluteScaleMin, configuredMin) : absoluteScaleMin;
        navScale.max = Number.isFinite(configuredMax) ? Math.min(absoluteScaleMax, configuredMax) : absoluteScaleMax;
        navScale.step = scaleStep;
        const storedScale = getStoredScale();
        selectedUiScale = storedScale !== null ? storedScale : (Number(data.scale) || defaultUiScale);
        navScaleControl.classList.toggle('visible', data.showScale === true);
        navMod.classList.toggle('visible', data.showMod === true);
        navMod.classList.toggle('active', data.modActive === true);
        navCoordinateList.innerHTML = '';
        const coordinates = data.coordinates || [];
        navCoordinates.classList.toggle('visible', coordinates.length > 0);
        coordinates.forEach((coordinate) => {
            const row = document.createElement('div');
            row.className = 'nav-coordinate-row';
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'nav-point';
            button.textContent = coordinate.label || String(coordinate.number);
            button.title = coordinate.title || `Point ${coordinate.label || coordinate.number}`;
            button.classList.toggle('selected', Number(data.selectedCoordinate) === Number(coordinate.number));
            button.addEventListener('click', () => {
                navCoordinateList.querySelectorAll('.nav-point').forEach((item) => item.classList.remove('selected'));
                button.classList.add('selected');
                send('navCoordinateSelect', { coordNumber: coordinate.number });
            });
            row.appendChild(button);
            if (coordinate.checkable === true) {
                const check = document.createElement('button');
                check.type = 'button';
                check.className = 'nav-point-check';
                check.classList.toggle('checked', coordinate.checked === true);
                check.textContent = coordinate.checked === true ? '\u2713' : '\u25a1';
                check.title = `Approve ${coordinate.label || coordinate.number}`;
                check.addEventListener('click', (event) => {
                    event.stopPropagation();
                    const checked = !check.classList.contains('checked');
                    check.classList.toggle('checked', checked);
                    check.textContent = checked ? '\u2713' : '\u25a1';
                    send('navCoordinateCheck', { coordNumber: coordinate.number, checked });
                });
                row.appendChild(check);
            }
            if (coordinate.deletable === true) {
                const remove = document.createElement('button');
                remove.type = 'button';
                remove.className = 'nav-point-delete';
                remove.textContent = '\u2212';
                remove.title = `Remove point ${coordinate.number}`;
                remove.addEventListener('click', () => send('navCoordinateDelete', { coordNumber: coordinate.number }));
                row.appendChild(remove);
            }
            navCoordinateList.appendChild(row);
        });
        navOptions.innerHTML = '';
        (data.options || []).forEach((option, index) => {
            const row = document.createElement('div');
            row.className = 'nav-option-row';
            row.classList.toggle('coordinate-row', option.coordinate === true);
            row.classList.toggle('gap-before', option.gapBefore === true);
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'nav-option';
            button.classList.toggle('nav-coordinate', option.coordinate === true);
            button.classList.toggle('nav-success', option.tone === 'success');
            button.classList.toggle('nav-danger', option.tone === 'danger');
            button.classList.toggle('nav-section', option.section === true);
            button.classList.toggle('has-right-label', Boolean(option.rightLabel));
            button.disabled = option.disabled === true;
            button.dataset.index = index + 1;
            button.dataset.description = option.description || '';
            if (option.rightLabel) {
                const label = document.createElement('span');
                label.className = 'nav-option-label';
                label.textContent = option.label;
                const rightLabel = document.createElement('span');
                rightLabel.className = 'nav-option-right';
                rightLabel.textContent = option.rightLabel;
                button.appendChild(label);
                button.appendChild(rightLabel);
            } else {
                button.textContent = option.label;
            }
            button.addEventListener('mouseenter', () => {
                if (button.disabled) return;
                const enabledButtons = Array.from(navOptions.querySelectorAll('.nav-option:not(:disabled)'));
                selectNavOption(enabledButtons.indexOf(button));
            });
            button.addEventListener('click', () => {
                const enabledButtons = Array.from(navOptions.querySelectorAll('.nav-option:not(:disabled)'));
                selectNavOption(enabledButtons.indexOf(button));
                send('navSelect', { index: index + 1 });
            });
            row.appendChild(button);
            if (option.coordBadge !== undefined && option.coordBadge !== null) {
                const badge = document.createElement('span');
                badge.className = 'nav-coord-badge';
                badge.textContent = String(option.coordBadge);
                badge.title = `Coordinate ${option.coordBadge}`;
                row.appendChild(badge);
            }
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
            if (option.checkable === true) {
                const checkButton = document.createElement('button');
                checkButton.type = 'button';
                checkButton.className = 'nav-check';
                checkButton.classList.toggle('checked', option.checked === true);
                checkButton.textContent = option.checked === true ? '\u2713' : '\u25a1';
                checkButton.title = `Approve ${option.label}`;
                checkButton.addEventListener('click', (event) => {
                    event.stopPropagation();
                    const checked = !checkButton.classList.contains('checked');
                    checkButton.classList.toggle('checked', checked);
                    checkButton.textContent = checked ? '\u2713' : '\u25a1';
                    send('navCheck', { index: index + 1, checked });
                });
                row.appendChild(checkButton);
            }
            navOptions.appendChild(row);
        });
        if (data.preserveScroll === true) navOptions.scrollTop = preservedOptionsScroll;
        renderNavFooterActions(data.footerActions || []);
        navReviewCamera.classList.toggle('visible', data.showReviewCamera === true);
        if (data.showReviewCamera === true) {
            navReviewZoom.min = data.reviewCameraMin !== undefined ? data.reviewCameraMin : 0.75;
            navReviewZoom.max = data.reviewCameraMax !== undefined ? data.reviewCameraMax : 8;
            navReviewZoom.step = data.reviewCameraStep !== undefined ? data.reviewCameraStep : 0.25;
            navReviewZoom.value = data.reviewCameraDistance !== undefined ? data.reviewCameraDistance : 3;
            navReviewZoomValue.textContent = `${Number(navReviewZoom.value).toFixed(2)} m`;
        }
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
        separatePoint.checked = false;
        separatePointOption.classList.toggle('hidden', data.showSeparatePoint !== true);
        editorCoordinates = data.coordinates || [];
        editorPoints = data.points || [];
        renderEditorCoordinates(data.selectedCoordinate ? `C${data.selectedCoordinate}` : null);
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
    if (data.action === 'editorPoints') {
        editorPoints = data.points || [];
        renderEditorCoordinates();
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
navMod.addEventListener('click', () => send('navMod'));
navReviewZoom.addEventListener('input', () => {
    navReviewZoomValue.textContent = `${Number(navReviewZoom.value).toFixed(2)} m`;
    send('navReviewZoom', { distance: Number(navReviewZoom.value) });
});

navScale.addEventListener('input', () => {
    applyNavScale(Number(navScale.value));
    send('navScale', { scale: selectedUiScale });
});

window.addEventListener('resize', () => updateViewportScaleMaximum());

document.querySelectorAll('[data-direction]').forEach((button) => {
    button.addEventListener('click', async () => {
        editorCoordList.querySelectorAll('.editor-coord').forEach((item) => item.classList.remove('selected'));
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
        editorCoordList.querySelectorAll('.editor-coord').forEach((item) => item.classList.remove('selected'));
        const response = await send('rotate', {
            direction: button.dataset.rotation,
            step: Number(movementStep.value),
        });
        const result = await response.json();
        if (result.offset) headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
    });
});

window.addEventListener('mousedown', (event) => {
    if (event.button !== 2) return;
    if (navigation.classList.contains('visible') && navReviewCamera.classList.contains('visible')) {
        event.preventDefault();
        send('navCameraLook');
        return;
    }
    if (!root.classList.contains('visible')) return;
    event.preventDefault();
    send('cameraLook');
});

window.addEventListener('contextmenu', (event) => event.preventDefault());

document.getElementById('confirm').addEventListener('click', () => {
    send('confirm', { separate: separatePoint.checked });
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
