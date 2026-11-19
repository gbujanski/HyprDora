.pragma library

// Geometry of a display layout: sizes after scaling, overlaps, and where screens go. Pure functions over
// monitor entries ({ name, x, y, width, height, scale, enabled, mirrorOf }), so they can be checked alone.

/**
 * Returns a monitor's width after scaling.
 * @param {object} monitor  monitor entry
 * @returns {int}
 */
function logicalWidth(monitor) {
    return Math.ceil(monitor.width / monitor.scale);
}

/**
 * Returns a monitor's height after scaling.
 * @param {object} monitor  monitor entry
 * @returns {int}
 */
function logicalHeight(monitor) {
    return Math.ceil(monitor.height / monitor.scale);
}

/**
 * Rearranges screens in a row if a size change made them overlap.
 * @param {list} list  monitor entries
 * @returns {list}
 */
function layoutWithoutOverlap(list) {
    return hasOverlap(list) ? arrangeInRow(list) : normalized(list);
}

/**
 * Tells whether any two active screens overlap.
 * @param {list} list  monitor entries
 * @returns {bool}
 */
function hasOverlap(list) {
    const active = list.filter(m => m.enabled && !m.mirrorOf);
    return active.some((a, i) => active.slice(i + 1).some(b => a.x < b.x + logicalWidth(b) && b.x < a.x + logicalWidth(a) && a.y < b.y + logicalHeight(b) && b.y < a.y + logicalHeight(a)));
}

/**
 * Places active screens side by side in their current order.
 * @param {list} list  monitor entries
 * @returns {list}
 */
function arrangeInRow(list) {
    const positions = {};
    let x = 0;
    for (const m of list.filter(o => o.enabled && !o.mirrorOf).sort((a, b) => a.x - b.x || a.name.localeCompare(b.name))) {
        positions[m.name] = x;
        x += logicalWidth(m);
    }
    return list.map(m => m.name in positions ? Object.assign({}, m, {
            x: positions[m.name],
            y: 0
        }) : m);
}

/**
 * Shifts active screens so the smallest coordinates are 0.
 * @param {list} list  monitor entries
 * @returns {list}
 */
function normalized(list) {
    const active = list.filter(m => m.enabled && !m.mirrorOf);
    if (active.length === 0)
        return list;
    const minX = Math.min(...active.map(m => m.x));
    const minY = Math.min(...active.map(m => m.y));
    return list.map(m => m.enabled && !m.mirrorOf ? Object.assign({}, m, {
            x: m.x - minX,
            y: m.y - minY
        }) : m);
}

/**
 * Finds the nearest free spot for a dropped screen along another screen's edge: either corner or the center
 * of that edge.
 * @param {object} moving  the dropped screen
 * @param {list} others  the other active screens
 * @param {int} x  drop position
 * @param {int} y  drop position
 * @returns {list} [x, y], or null when no spot is free
 */
function snapPosition(moving, others, x, y) {
    const w = logicalWidth(moving);
    const h = logicalHeight(moving);
    const clear = (cx, cy) => others.every(o => cx >= o.x + logicalWidth(o) || o.x >= cx + w || cy >= o.y + logicalHeight(o) || o.y >= cy + h);
    let best = null;
    let bestDistance = Infinity;
    for (const o of others) {
        const ow = logicalWidth(o);
        const oh = logicalHeight(o);
        const centerX = o.x + Math.round((ow - w) / 2);
        const centerY = o.y + Math.round((oh - h) / 2);
        const candidates = [[o.x - w, o.y], [o.x - w, centerY], [o.x - w, o.y + oh - h], [o.x + ow, o.y], [o.x + ow, centerY], [o.x + ow, o.y + oh - h], [o.x, o.y - h], [centerX, o.y - h], [o.x + ow - w, o.y - h], [o.x, o.y + oh], [centerX, o.y + oh], [o.x + ow - w, o.y + oh]];
        for (const [cx, cy] of candidates) {
            const distance = Math.hypot(cx - x, cy - y);
            if (distance < bestDistance && clear(cx, cy)) {
                best = [cx, cy];
                bestDistance = distance;
            }
        }
    }
    return best;
}
