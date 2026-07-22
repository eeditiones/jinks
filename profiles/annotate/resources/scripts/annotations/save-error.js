/**
 * Show a helpful error dialog when saving or merging annotations fails.
 */
(function () {
	function msg(key) {
		const el = document.getElementById(`i18n-${key}`);
		return el?.textContent?.trim() || key;
	}

	function cleanDescription(description) {
		return description.replace(/\s*\[at line \d+.*$/s, '').trim();
	}

	async function serverDetail(response) {
		try {
			const body = await response.clone().json();
			if (body.description) {
				return cleanDescription(body.description);
			}
			if (body.message) {
				return body.message;
			}
		} catch (_) {
			// ignore non-JSON bodies
		}
		return response.statusText || '';
	}

	async function showSaveError(response) {
		const dialog = document.getElementById('error-dialog');
		const title = dialog.title;

		if (response.status === 403) {
			document.getElementById('permission-denied-dialog').show();
			return;
		}

		if (response.status === 401) {
			document.getElementById('login-required-dialog').show();
			return;
		}

		const detail = await serverDetail(response);
		const message = detail
			? `${msg('save-failed')}: ${detail}`
			: `${msg('save-failed')} (HTTP ${response.status})`;
		dialog.show(title, message);
	}

	function showNetworkError() {
		const dialog = document.getElementById('error-dialog');
		dialog.show(dialog.title, msg('save-network-error'));
	}

	window.showSaveError = showSaveError;
	window.showNetworkError = showNetworkError;
})();
