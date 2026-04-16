import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

const args = process.argv.slice(2);

const FORCE = args.includes('-force');
const positional = args.filter(arg => arg !== '-force');

const WORK_DIR = path.resolve(positional[0] || './images');
const ORIGINAL_DIR = path.resolve(positional[1] || './originals');

const SUPPORTED = new Set([
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.tif',
    '.tiff',
]);

function isInside(child, parent) {
    const rel = path.relative(parent, child);
    return rel && !rel.startsWith('..') && !path.isAbsolute(rel);
}

function isSameOrInside(child, parent) {
    return child === parent || isInside(child, parent);
}

async function walk(dir) {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    const files = [];

    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);

        // Never recurse into the originals directory
        if (isSameOrInside(fullPath, ORIGINAL_DIR)) {
            continue;
        }

        if (entry.isDirectory()) {
            files.push(...await walk(fullPath));
        } else if (entry.isFile()) {
            files.push(fullPath);
        }
    }

    return files;
}

async function ensureParentDir(filePath) {
    await fs.mkdir(path.dirname(filePath), { recursive: true });
}

async function exists(filePath) {
    try {
        await fs.access(filePath);
        return true;
    } catch {
        return false;
    }
}

function isSupported(filePath) {
    return SUPPORTED.has(path.extname(filePath).toLowerCase());
}

function getRelativePath(filePath) {
    return path.relative(WORK_DIR, filePath);
}

function getBackupPath(filePath) {
    return path.join(ORIGINAL_DIR, getRelativePath(filePath));
}

async function backupOriginal(filePath) {
    const backupPath = getBackupPath(filePath);

    await ensureParentDir(backupPath);

    if (!(await exists(backupPath))) {
        await fs.copyFile(filePath, backupPath);
        console.log(`copy   ${getRelativePath(filePath)}`);
    }

    return backupPath;
}

async function compressInPlace(filePath) {
    if (!isSupported(filePath)) return;

    const ext = path.extname(filePath).toLowerCase();
    const relative = getRelativePath(filePath);
    const backupPath = getBackupPath(filePath);
    const tempPath = `${filePath}.__tmp__`;

    const alreadyProcessed = await exists(backupPath);

    if (alreadyProcessed && !FORCE) {
        console.log(`skip   ${relative} (already processed)`);
        return;
    }

    try {
        if (!alreadyProcessed) {
            await backupOriginal(filePath);
        } else {
            console.log(`force  ${relative}`);
        }

        let img = sharp(filePath, { animated: true });

        switch (ext) {
            case '.jpg':
            case '.jpeg':
                img = img.jpeg({
                    quality: 80,
                    mozjpeg: true,
                });
                break;

            case '.png':
                img = img.png({
                    compressionLevel: 9,
                    palette: true,
                    quality: 80,
                });
                break;

            case '.webp':
                img = img.webp({
                    quality: 80,
                });
                break;

            case '.gif':
                img = img.gif({
                    effort: 7,
                    colours: 128,
                });
                break;

            case '.tif':
            case '.tiff':
                img = img.tiff({
                    quality: 80,
                    compression: 'jpeg',
                });
                break;

            default:
                return;
        }

        await img.toFile(tempPath);
        await fs.rename(tempPath, filePath);

        const originalStat = await fs.stat(backupPath);
        const compressedStat = await fs.stat(filePath);
        const saved = originalStat.size - compressedStat.size;
        const pct =
            originalStat.size > 0
                ? ((saved / originalStat.size) * 100).toFixed(1)
                : '0.0';

        console.log(`done   ${relative}  saved ${saved} bytes (${pct}%)`);
    } catch (err) {
        console.error(`error  ${relative}: ${err.message}`);

        try {
            if (await exists(tempPath)) {
                await fs.unlink(tempPath);
            }
        } catch {
            // ignore cleanup errors
        }
    }
}

async function main() {
    if (isSameOrInside(ORIGINAL_DIR, WORK_DIR)) {
        console.log(`note   originals dir is inside work dir and will be excluded from processing`);
    }

    const files = await walk(WORK_DIR);

    for (const file of files) {
        await compressInPlace(file);
    }
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});