document.addEventListener('DOMContentLoaded', function () {
    var currentPage = 1;
    var pages = document.querySelectorAll('.page');
    var links = document.querySelectorAll('.page-link');
    var prevPageLinks = document.querySelectorAll('#prev-page-top, #prev-page-bottom');
    var nextPageLinks = document.querySelectorAll('#next-page-top, #next-page-bottom');
    var total_pages = parseInt(document.querySelector('#pagination-top').getAttribute('data-total-pages'));
    var images = document.querySelectorAll('img[data-src]');
    var config = {
        rootMargin: '0px 0px 50px 0px',
        threshold: 0
    };
    var imageObserver = new IntersectionObserver(function (entries, self) {
        entries.forEach(function (entry) {
            if (entry.isIntersecting) {
                preloadImage(entry.target);
                self.unobserve(entry.target);
            }
        });
    }, config);
    images.forEach(function (image) {
        imageObserver.observe(image);
    });
    function preloadImage(img) {
        var src = img.getAttribute('data-src');
        if (!src) {
            return;
        }
        img.src = src;
    }
    function showPage(page) {
        pages.forEach(function (pageDiv) {
            pageDiv.style.display = pageDiv.getAttribute('data-page') == page.toString() ? 'block' : 'none';
        });
        currentPage = page;
        prevPageLinks.forEach(function (link) {
            link.style.visibility = currentPage == 1 ? 'hidden' : 'visible';
        });
        nextPageLinks.forEach(function (link) {
            link.style.visibility = currentPage == total_pages ? 'hidden' : 'visible';
        });
        // Remove the current-page class from all links
        links.forEach(function (link) {
            link.classList.remove('current-page');
            if (link.parentElement) {
                link.parentElement.classList.remove('active');
            }
        });
        // Add the current-page class to the current page links
        var currentPageLinks = document.querySelectorAll('.page-link[data-page="' + currentPage + '"]');
        if (currentPageLinks) {
            currentPageLinks.forEach(function (link) {
                link.classList.add('current-page');
                if (link.parentElement) {
                    link.parentElement.classList.add('active');
                }
            });
        }
    }
    links.forEach(function (link) {
        link.addEventListener('click', function (e) {
            e.preventDefault();
            var page = parseInt(link.getAttribute('data-page')); // Convert the page attribute to a number
            if (page) {
                showPage(page);
            }
        });
    });
    prevPageLinks.forEach(function (link) {
        link.addEventListener('click', function (e) {
            e.preventDefault();
            if (currentPage > 1)
                showPage(currentPage - 1);
        });
    });
    nextPageLinks.forEach(function (link) {
        link.addEventListener('click', function (e) {
            e.preventDefault();
            if (currentPage < total_pages)
                showPage(currentPage + 1);
        });
    });
    showPage(currentPage);
});
function scrollToTop() {
    window.scrollTo({
        top: 0,
        behavior: 'smooth'
    });
}
