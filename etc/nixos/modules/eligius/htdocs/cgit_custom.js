window.addEventListener('DOMContentLoaded', () => {
    // only execute this on the main repository index page
    if (window.location.pathname === "/git" || window.location.pathname === "/git/") {

        // target the main repository name links (ignores the summary/commit/tree tags)
        const repoLinks = document.querySelectorAll("td.toplevel-repo a, td.sublevel-repo a");

        repoLinks.forEach(link => {
            let href = link.getAttribute('href');
            if (href && !href.endsWith("/about/")) {
                // ensure a trailing slash exists, then append 'about/'
                if (!href.endsWith("/")) href += "/";
                link.setAttribute('href', href + "about/");
            }
        });
    }
});
