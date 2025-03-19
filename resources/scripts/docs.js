document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.source').forEach(link => {
        link.addEventListener('click', (ev) => {
            ev.preventDefault();

            // Check if editor already exists after this link
            let editor = link.nextElementSibling;
            if (editor && editor.tagName.toLowerCase() === 'jinn-monaco-editor') {
                editor.remove();
                return;
            }

            // Create new editor
            editor = document.createElement('jinn-monaco-editor');
            editor.style.height = '400px';
            editor.style.marginTop = '1em';
            
            // Get relative URL from href and load content
            const url = link.getAttribute('href');
            editor.url = url;

            // Insert after the link
            link.parentNode.insertBefore(editor, link.nextSibling);
        });
    });

    // Handle image popups
    const figures = document.querySelectorAll('figure');
    
    figures.forEach(figure => {
        const popup = document.querySelector('.image-popup');
        const popupImg = popup.querySelector('img');
        const figureImg = figure.querySelector('img');
        
        if (popup && figureImg) {
            figure.addEventListener('click', () => {
                popupImg.src = figureImg.src;
                popup.style.display = 'block';
            });
            
            popup.addEventListener('click', () => {
                popup.style.display = 'none';
            });
            
            // Close popup on escape key
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape' && popup.style.display === 'block') {
                    popup.style.display = 'none';
                }
            });
        }
    });
});