document.addEventListener('DOMContentLoaded', function() {
    let currentPage: number = 1;
    const pages: NodeListOf<Element> = document.querySelectorAll('.page');
    const links: NodeListOf<Element> = document.querySelectorAll('.page-link');
    const prevPageLinks: NodeListOf<Element> = document.querySelectorAll('#prev-page-top, #prev-page-bottom');
    const nextPageLinks: NodeListOf<Element> = document.querySelectorAll('#next-page-top, #next-page-bottom');
    const total_pages: number = parseInt(document.querySelector('#pagination-top')!.getAttribute('data-total-pages')!);

    const images: NodeListOf<HTMLImageElement> = document.querySelectorAll('img[data-src]');
    const config: IntersectionObserverInit = {
        rootMargin: '0px 0px 50px 0px',
        threshold: 0
    };

    const imageObserver: IntersectionObserver = new IntersectionObserver(function(entries, self) {
        entries.forEach(function(entry) {
            if (entry.isIntersecting) {
                preloadImage(entry.target as HTMLImageElement);
                self.unobserve(entry.target);
            }
        });
    }, config);

    images.forEach(function(image) {
        imageObserver.observe(image);
    });

    function preloadImage(img: HTMLImageElement) {
        const src: string | null = img.getAttribute('data-src');
        if (!src) {
            return;
        }
        img.src = src;
    }

    function showPage(page: number) {
        pages.forEach(function(pageDiv: Element) {
            pageDiv.style.display = pageDiv.getAttribute('data-page') == page.toString() ? 'block' : 'none';
        });
        currentPage = page;
        prevPageLinks.forEach(function(link: Element) {
            link.style.visibility = currentPage == 1 ? 'hidden' : 'visible';
        });
        nextPageLinks.forEach(function(link: Element) {
            link.style.visibility = currentPage == total_pages ? 'hidden' : 'visible';
        });

        // Remove the current-page class from all links
        links.forEach(function(link: Element) {
            link.classList.remove('current-page');
            if (link.parentElement) {
                link.parentElement.classList.remove('active');
            }
        });

        // Add the current-page class to the current page links
        const currentPageLinks: NodeListOf<Element> = document.querySelectorAll('.page-link[data-page="' + currentPage + '"]');
        if (currentPageLinks) {
            currentPageLinks.forEach(function(link: Element) {
                link.classList.add('current-page');
                if (link.parentElement) {
                    link.parentElement.classList.add('active');
                }
            });
        }

        const mobileSpans: NodeListOf<Element> = document.querySelectorAll('.mobile-span');
        mobileSpans.forEach(function(span: Element) {
            span.textContent = currentPage.toString();
        });

    }

    links.forEach(function(link: Element) {
        link.addEventListener('click', function(e: Event) {
            e.preventDefault();
            const page: number = parseInt(link.getAttribute('data-page')!); // Convert the page attribute to a number
            if (page) {
                showPage(page);
            }
        });
    });

    prevPageLinks.forEach(function(link: Element) {
        link.addEventListener('click', function(e: Event) {
            e.preventDefault();
            if (currentPage > 1) showPage(currentPage - 1);
        });
    });

    nextPageLinks.forEach(function(link: Element) {
        link.addEventListener('click', function(e: Event) {
            e.preventDefault();
            if (currentPage < total_pages) showPage(currentPage + 1);
        });
    });
    showPage(currentPage);
});

function scrollToTop() {
    document.documentElement.scrollTo({
        top: 0,
        behavior: 'smooth'
    });
}