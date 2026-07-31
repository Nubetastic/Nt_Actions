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
const manualOffsetFields = document.getElementById('manual-offset-fields');
const movementControls = document.getElementById('movement-controls');
const manualOffsetError = document.getElementById('manual-offset-error');
const offsetInputs = ['x', 'y', 'z', 'heading'].reduce((result, key) => {
    result[key] = document.getElementById(`offset-${key}`);
    return result;
}, {});
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
const groupEditor = document.getElementById('group-editor');
const groupEditorGroups = document.getElementById('group-editor-groups');
const groupEditorError = document.getElementById('group-editor-error');
const groupEditorNew = document.getElementById('group-editor-new');
const groupEditorCancel = document.getElementById('group-editor-cancel');
const groupEditorSave = document.getElementById('group-editor-save');
let groupDraft = [];

const renderNavFooterActions = (actions = []) => {
    navFooterActions.innerHTML = '';
    actions.forEach((action, index) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = action.label;
        button.disabled = action.disabled === true;
        button.classList.toggle('danger', action.danger === true);
        button.classList.toggle('wide', action.wide === true);
        button.addEventListener('click', () => send('navFooter', { index: index + 1 }));
        navFooterActions.appendChild(button);
    });
    navFooterActions.style.display = actions.length ? 'grid' : 'none';
};
const navCoordinates = document.getElementById('nav-coordinates');
const navCoordinateList = document.getElementById('nav-coordinate-list');
const navGroupEdit = document.getElementById('nav-group-edit');
const navPreset = document.getElementById('nav-preset');
const presetEditor = document.getElementById('preset-editor');
const presetList = document.getElementById('preset-list');
const presetTitle = document.getElementById('preset-title');
const presetSummary = document.getElementById('preset-summary');
const presetPoint = document.getElementById('preset-point');
const presetPoses = document.getElementById('preset-poses');
const presetApply = document.getElementById('preset-apply');
const presetName = document.getElementById('preset-name');
const presetError = document.getElementById('preset-error');
let presetData = [];
let selectedPreset = -1;
const presetCompare = document.getElementById('preset-compare');
const compareExisting = document.getElementById('compare-existing');
const compareLeft = document.getElementById('compare-left');
const compareRight = document.getElementById('compare-right');
const compareSummary = document.getElementById('compare-summary');
const compareError = document.getElementById('compare-error');
let comparePage = null;
let compareDraft = { existingPreset: '', replacePreset: false, checkedPoses: {}, checkedObjects: {} };
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

const offsetInputValue = () => Object.fromEntries(
    Object.entries(offsetInputs).map(([key, input]) => [key, Number(input.value)])
);
const setOffsetInputs = (offset = {}) => Object.entries(offsetInputs).forEach(([key, input]) => {
    input.value = Number(offset[key] || 0).toFixed(key === 'heading' ? 1 : 3);
});

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

const closeGroupEditor = () => {
    groupEditor.classList.remove('visible');
    groupEditor.setAttribute('aria-hidden', 'true');
    groupDraft = [];
    groupEditorGroups.innerHTML = '';
    groupEditorError.textContent = '';
};

const groupNameForNewCard = () => {
    const used = new Set(groupDraft.map((group) => group.name.trim().toLowerCase()));
    let number = 1;
    while (used.has(`group ${number}`)) number += 1;
    return `Group ${number}`;
};

const moveGroupEntry = (sourceIndex, destinationIndex, collection, itemIndex) => {
    if (sourceIndex === destinationIndex || !groupDraft[destinationIndex]) return;
    const [item] = groupDraft[sourceIndex][collection].splice(itemIndex, 1);
    if (item) groupDraft[destinationIndex][collection].push(item);
    renderGroupEditor();
};

const destinationSelect = (sourceIndex, collection, itemIndex) => {
    const select = document.createElement('select');
    select.title = 'Move to group';
    groupDraft.forEach((group, index) => {
        const option = document.createElement('option');
        option.value = index;
        option.textContent = index === sourceIndex ? 'Keep here' : `Move to ${group.name || `Group ${index + 1}`}`;
        option.selected = index === sourceIndex;
        select.appendChild(option);
    });
    select.addEventListener('change', () => moveGroupEntry(sourceIndex, Number(select.value), collection, itemIndex));
    return select;
};

const renderGroupItems = (container, groupIndex, collection) => {
    const items = groupDraft[groupIndex][collection];
    if (!items.length) {
        const empty = document.createElement('div');
        empty.className = 'group-empty';
        empty.textContent = collection === 'points' ? 'No points' : 'No poses';
        container.appendChild(empty);
        return;
    }
    items.forEach((item, itemIndex) => {
        const row = document.createElement('div');
        row.className = 'group-item';
        const label = document.createElement('div');
        label.className = 'group-item-label';
        label.textContent = item.label;
        if (collection === 'poses') {
            const meta = document.createElement('span');
            meta.className = 'group-item-meta';
            meta.textContent = `${item.group} ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡/ ${item.visibility}`;
            label.appendChild(meta);
        } else if (item.title) {
            const meta = document.createElement('span');
            meta.className = 'group-item-meta';
            meta.textContent = item.title;
            label.appendChild(meta);
        }
        row.appendChild(label);
        row.appendChild(destinationSelect(groupIndex, collection, itemIndex));
        container.appendChild(row);
    });
};

const renderGroupEditor = () => {
    groupEditorGroups.innerHTML = '';
    groupDraft.forEach((group, groupIndex) => {
        const card = document.createElement('section');
        card.className = 'group-card';
        const header = document.createElement('header');
        header.className = 'group-card-header';
        const name = document.createElement('input');
        name.className = 'group-card-name';
        name.maxLength = 64;
        name.value = group.name;
        name.setAttribute('aria-label', `Group ${groupIndex + 1} name`);
        name.addEventListener('input', () => { group.name = name.value; });
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'group-card-remove';
        remove.textContent = 'Remove';
        remove.disabled = groupDraft.length <= 1 || group.points.length > 0 || group.poses.length > 0;
        remove.title = remove.disabled ? 'Move all points and poses out of this group first' : 'Remove empty group';
        remove.addEventListener('click', () => { groupDraft.splice(groupIndex, 1); renderGroupEditor(); });
        const counts = document.createElement('div');
        counts.className = 'group-card-counts';
        counts.textContent = `${group.points.length} point${group.points.length === 1 ? '' : 's'} ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡/ ${group.poses.length} pose${group.poses.length === 1 ? '' : 's'}`;
        header.append(name, remove, counts);
        card.appendChild(header);
        const body = document.createElement('div');
        body.className = 'group-card-body';
        const points = document.createElement('div');
        points.className = 'group-list';
        points.innerHTML = '<div class="group-list-title">POINTS</div>';
        renderGroupItems(points, groupIndex, 'points');
        const poses = document.createElement('div');
        poses.className = 'group-list';
        poses.innerHTML = '<div class="group-list-title">POSES</div>';
        renderGroupItems(poses, groupIndex, 'poses');
        body.append(points, poses);
        card.appendChild(body);
        groupEditorGroups.appendChild(card);
    });
};

const validateGroupDraft = () => {
    const names = new Set();
    for (const group of groupDraft) {
        const name = group.name.trim();
        if (!name) return 'Every group needs a name.';
        if (names.has(name.toLowerCase())) return 'Group names must be unique.';
        names.add(name.toLowerCase());
        if (group.poses.length && !group.points.length) return `${name} has poses but no points.`;
    }
    return '';
};
const renderPreset = () => {
    presetList.innerHTML = '';
    presetData.forEach((preset, index) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.classList.toggle('active', index === selectedPreset);
        button.textContent = `${preset.name}${preset.active ? ' (Active)' : ''}`;
        button.addEventListener('click', () => { selectedPreset = index; renderPreset(); });
        presetList.appendChild(button);
    });
    const preset = presetData[selectedPreset];
    presetApply.disabled = !preset;
    presetApply.textContent = preset && preset.active ? 'Remove from Object' : 'Apply to Object';
    presetApply.classList.toggle('danger', Boolean(preset && preset.active));
    presetPoint.innerHTML = '';
    presetPoses.innerHTML = '';
    if (!preset) { presetTitle.textContent = 'Select a preset'; presetSummary.textContent = ''; presetName.value = ''; return; }
    presetTitle.textContent = preset.name;
    presetName.value = preset.name;
    presetSummary.textContent = `${preset.points.length} points ÃƒÆ’Ã¢â‚¬Å¡/ ${preset.poses.length} poses${preset.active ? ' ÃƒÆ’Ã¢â‚¬Å¡/ linked to this object' : ''}`;
    preset.points.forEach((point, index) => {
        const option = document.createElement('option'); option.value = index; option.textContent = point.label; presetPoint.appendChild(option);
    });
    preset.poses.forEach((pose) => {
        const button = document.createElement('button'); button.type = 'button'; button.className = 'preset-pose';
        button.innerHTML = `<span></span><small></small>`;
        button.querySelector('span').textContent = pose.label;
        button.querySelector('small').textContent = `${pose.pointGroup} ÃƒÆ’Ã¢â‚¬Å¡/ ${pose.visibility}`;
        button.disabled = preset.points.length === 0;
        button.addEventListener('click', () => send('presetPreview', { preset: preset.name, pose: pose.scenario, point: Number(presetPoint.value) + 1 }));
        presetPoses.appendChild(button);
    });
};
const compareKey = (pose) => `${pose.group}\u0000${pose.scenario}`;
const compareRow = (label, check, disabled, checked, onToggle) => {
    const row = document.createElement('div'); row.className = 'compare-row';
    const text = document.createElement('span'); text.textContent = label; row.appendChild(text);
    if (check) { const button = document.createElement('button'); button.className = `compare-check${checked ? ' checked' : ''}`; button.textContent = checked ? '✓' : '□'; button.disabled = disabled; button.addEventListener('click', () => onToggle(!checked)); row.appendChild(button); }
    return row;
};
const compareSection = (root, title) => { const node = document.createElement('div'); node.className = 'compare-section'; node.textContent = title; root.appendChild(node); };
const renderCompare = () => {
    if (!comparePage) return;
    const liveEntries = (comparePage.destinations || []).filter((entry) => !entry.candidate);
    compareExisting.innerHTML = '<option value="">No existing preset</option>';
    liveEntries.forEach((entry) => { const option = document.createElement('option'); option.value = entry.name; option.textContent = entry.name; compareExisting.appendChild(option); });
    compareExisting.value = compareDraft.existingPreset || '';
    const live = liveEntries.find((entry) => entry.name === compareDraft.existingPreset);
    const existingPoses = new Set(((live && live.definition.poses) || []).map(compareKey));
    compareLeft.innerHTML = ''; compareRight.innerHTML = '';
    document.getElementById('compare-left-title').textContent = live ? live.name : 'No Existing Preset';
    document.getElementById('compare-right-title').textContent = comparePage.candidateName;
    compareSection(compareLeft, 'Poses');
    ((live && live.definition.poses) || []).forEach((pose) => compareLeft.appendChild(compareRow(pose.scenario, false)));
    compareSection(compareLeft, 'Items Using Preset');
    ((live && live.items) || []).forEach((item) => compareLeft.appendChild(compareRow(String(item), false)));
    compareSection(compareRight, 'Preset Name');
    compareRight.appendChild(compareRow(`Replace with ${comparePage.candidateName}`, true, false, compareDraft.replacePreset, (value) => { compareDraft.replacePreset = value; renderCompare(); }));
    compareSection(compareRight, 'Poses');
    ((comparePage.candidateDefinition && comparePage.candidateDefinition.poses) || []).forEach((pose) => {
        const key = compareKey(pose); const duplicate = existingPoses.has(key); const disabled = compareDraft.replacePreset || duplicate;
        compareRight.appendChild(compareRow(`${pose.scenario}${duplicate ? ' (Already Exists)' : ''}`, true, disabled, compareDraft.replacePreset || compareDraft.checkedPoses[key] === true, (value) => { compareDraft.checkedPoses[key] = value; renderCompare(); }));
    });
    compareSection(compareRight, 'Objects');
    (comparePage.objects || []).forEach((object) => { const key = String(object.item); const assigned = object.currentPreset === compareDraft.existingPreset && !compareDraft.replacePreset; compareRight.appendChild(compareRow(`${key}${assigned ? ' (Already Assigned)' : ''}`, true, assigned, compareDraft.checkedObjects[key] === true, (value) => { compareDraft.checkedObjects[key] = value; renderCompare(); })); });
    const poseCount = Object.values(compareDraft.checkedPoses).filter(Boolean).length; const objectCount = Object.values(compareDraft.checkedObjects).filter(Boolean).length;
    compareSummary.textContent = compareDraft.replacePreset ? `Replace preset; assign ${objectCount} checked objects` : `Add ${poseCount} poses; assign ${objectCount} objects`;
    document.getElementById('compare-apply').disabled = !compareDraft.replacePreset && !compareDraft.existingPreset;
};
window.addEventListener('message', ({ data }) => {
    if (data.action === 'presetCompareOpen') {
        comparePage = data.page; const old = data.draft || {}; const liveEntries = (comparePage.destinations || []).filter((entry) => !entry.candidate); const displayedObject = (comparePage.objects || [])[Math.max(0, (Number(old.objectIndex) || 1) - 1)]; const assignedPreset = displayedObject && liveEntries.some((entry) => entry.name === displayedObject.currentPreset) ? displayedObject.currentPreset : ''; compareDraft.existingPreset = old.existingPreset || assignedPreset || (liveEntries.some((entry) => entry.name === comparePage.candidateName) ? comparePage.candidateName : ''); compareDraft.replacePreset = old.replacePreset === true; compareDraft.checkedPoses = old.checkedPoses || {}; compareDraft.checkedObjects = old.checkedObjects || {}; compareError.textContent = ''; presetCompare.classList.add('visible'); presetCompare.setAttribute('aria-hidden', 'false'); renderCompare(); return;
    }
    if (data.action === 'presetCompareClose') { presetCompare.classList.remove('visible'); presetCompare.setAttribute('aria-hidden', 'true'); return; }
    if (data.action === 'presetOpen') {
        presetData = data.presets || []; selectedPreset = Math.max(0, presetData.findIndex((item) => item.active));
        presetError.textContent = ''; renderPreset(); navigation.classList.remove('visible');
        presetEditor.classList.add('visible'); presetEditor.setAttribute('aria-hidden', 'false'); return;
    }
    if (data.action === 'presetClose') { presetEditor.classList.remove('visible'); presetEditor.setAttribute('aria-hidden', 'true'); return; }
    if (data.action === 'groupEditorOpen') {
        groupDraft = JSON.parse(JSON.stringify(data.groups || []));
        groupEditorError.textContent = '';
        renderGroupEditor();
        navigation.classList.remove('visible');
        navigation.setAttribute('aria-hidden', 'true');
        groupEditor.classList.add('visible');
        groupEditor.setAttribute('aria-hidden', 'false');
        return;
    }
    if (data.action === 'groupEditorClose') { closeGroupEditor(); return; }
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
        navCoordinates.classList.toggle('visible',
            coordinates.length > 0 || data.showGroupEdit === true || data.showPreset === true);
        let previousPointGroup = null;
        coordinates.forEach((coordinate) => {
            if (coordinate.pointGroup && coordinate.pointGroup !== previousPointGroup) {
                const heading = document.createElement('div');
                heading.className = 'nav-point-group';
                heading.textContent = coordinate.pointGroup;
                navCoordinateList.appendChild(heading);
                previousPointGroup = coordinate.pointGroup;
            }
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
        navGroupEdit.classList.toggle('visible', data.showGroupEdit === true);
        navPreset.classList.toggle('visible', data.showPreset === true);
        navPreset.textContent = data.presetLabel || 'Presets';
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
        manualOffsetFields.classList.toggle('hidden', data.manualOffset !== true);
        movementControls.classList.toggle('locked', data.movementLocked === true);
        document.getElementById('move-set').disabled = data.canMoveSet !== true;
        manualOffsetError.textContent = '';
        if (data.manualOffset === true) {
            const formatCoordinates = (coords = {}) => ['x', 'y', 'z']
                .map((key) => Number(coords[key] || 0).toFixed(3)).join(', ');
            document.getElementById('player-coordinates').textContent = formatCoordinates(data.playerCoordinates);
            document.getElementById('object-coordinates').textContent = formatCoordinates(data.objectCoordinates);
            setOffsetInputs(data.offset);
        }
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
navGroupEdit.addEventListener('click', () => send('navGroupEdit'));
navPreset.addEventListener('click', () => send('navPreset'));
document.getElementById('preset-close').addEventListener('click', () => send('presetClose'));
presetApply.addEventListener('click', async () => {
    const preset = presetData[selectedPreset]; if (!preset) return;
    const remove = preset.active === true;
    presetApply.disabled = true;
    const response = await send('presetApply', { name: preset.name, remove });
    const result = await response.json();
    if (!result.ok) {
        presetError.textContent = result.error || 'Preset assignment could not be changed.';
        presetApply.disabled = false;
    }
});
document.getElementById('preset-rename').addEventListener('click', async () => {
    const preset = presetData[selectedPreset];
    const name = presetName.value.trim();
    if (!preset) { presetError.textContent = 'Select a preset to rename.'; return; }
    if (!name) { presetError.textContent = 'Enter a preset name.'; return; }
    const response = await send('presetRename', { oldName: preset.name, name });
    const result = await response.json();
    if (!result.ok) presetError.textContent = result.error || 'Preset could not be renamed.';
});
groupEditorNew.addEventListener('click', () => {
    groupDraft.push({ name: groupNameForNewCard(), points: [], poses: [] });
    renderGroupEditor();
    groupEditorGroups.scrollLeft = groupEditorGroups.scrollWidth;
});
groupEditorCancel.addEventListener('click', () => send('groupEditorCancel'));
groupEditorSave.addEventListener('click', async () => {
    const error = validateGroupDraft();
    groupEditorError.textContent = error;
    if (error) return;
    groupEditorSave.disabled = true;
    const groups = groupDraft.map((group) => ({
        name: group.name.trim(),
        points: group.points.map((point) => point.index),
        poses: group.poses.map((pose) => ({ group: pose.group, scenario: pose.scenario })),
    }));
    try {
        const response = await send('groupEditorSave', { groups });
        const result = await response.json();
        if (!result.ok) groupEditorError.textContent = result.error || 'Groups could not be saved.';
    } finally {
        groupEditorSave.disabled = false;
    }
});
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
        if (result.offset) {
            headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
            if (!manualOffsetFields.classList.contains('hidden')) setOffsetInputs(result.offset);
        }
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
        if (result.offset) {
            headingValue.textContent = `${Math.round(result.offset.heading)}\u00B0`;
            if (!manualOffsetFields.classList.contains('hidden')) setOffsetInputs(result.offset);
        }
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
    send('confirm', { separate: separatePoint.checked, offset: offsetInputValue() });
});
document.getElementById('move-set').addEventListener('click', async () => {
    manualOffsetError.textContent = '';
    const response = await send('moveSet', { offset: offsetInputValue() });
    const result = await response.json();
    if (!result.ok) {
        manualOffsetError.textContent = result.error || 'Move Set could not be started.';
        return;
    }
    movementControls.classList.remove('locked');
    document.getElementById('move-set').disabled = true;
    if (result.offset) setOffsetInputs(result.offset);
});

document.getElementById('cancel').addEventListener('click', () => send('cancel'));

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && presetCompare.classList.contains('visible')) { send('presetCompareReview', { draft: compareDraft }); return; }
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
    if (event.key === 'Escape' && presetEditor.classList.contains('visible')) { send('presetClose'); return; }
    if (event.key === 'Escape' && groupEditor.classList.contains('visible')) { send('groupEditorCancel'); return; }
    if (event.key === 'Escape' && root.classList.contains('visible')) send('cancel');
});
compareExisting.addEventListener('change', () => { compareDraft.existingPreset = compareExisting.value; compareDraft.checkedPoses = {}; renderCompare(); });
document.getElementById('compare-review').addEventListener('click', () => send('presetCompareReview', { draft: compareDraft }));
document.getElementById('compare-cancel').addEventListener('click', () => send('presetCompareReview', { draft: compareDraft }));
document.getElementById('compare-apply').addEventListener('click', async () => {
    const checkedPoses = [];
    ((comparePage.candidateDefinition && comparePage.candidateDefinition.poses) || []).forEach((pose) => { if (compareDraft.checkedPoses[compareKey(pose)]) checkedPoses.push({ group: pose.group, scenario: pose.scenario }); });
    const checkedObjects = Object.entries(compareDraft.checkedObjects).filter(([, value]) => value).map(([key]) => Number(key));
    const response = await send('presetCompareApply', { existingPreset: compareDraft.existingPreset, replacePreset: compareDraft.replacePreset, checkedPoses, checkedObjects }); const result = await response.json();
    if (!result.ok) compareError.textContent = result.error || 'Comparison could not be applied.';
});
