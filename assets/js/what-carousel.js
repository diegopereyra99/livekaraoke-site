(() => {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.carousel').forEach(initCarousel);
  });

  function initCarousel(root){
    if(root.dataset.initialized) return; // avoid double init
    root.dataset.initialized = 'true';

    const track = root.querySelector('.track');
    const dotsWrap = root.querySelector('.dots');
    if(!track) return;

    const getSlides = () => Array.from(track.querySelectorAll('.slide'));

    // Ensure slide IDs exist for a11y
    getSlides().forEach((s, i) => { if(!s.id) s.id = `carousel-slide-${i+1}`; });

    // Build dots based on slides
    function buildDots(){
      if(!dotsWrap) return;
      dotsWrap.innerHTML = '';
      getSlides().forEach((slide, i) => {
        const dot = document.createElement('button');
        dot.className = 'dot';
        dot.type = 'button';
        dot.setAttribute('role', 'tab');
        dot.setAttribute('aria-controls', slide.id);
        dot.setAttribute('aria-label', `Go to slide ${i+1}`);
        dot.addEventListener('click', () => scrollToIndex(i, true));
        dotsWrap.appendChild(dot);
      });
    }
    buildDots();

    const dots = () => dotsWrap ? Array.from(dotsWrap.querySelectorAll('.dot')) : [];
    let current = 0;
    let autoplayTimer = null;
    let hover = false, focus = false, pointerDown = false;

    // Active state sync
    function setActive(idx){
      current = idx;
      if(dotsWrap){
        dots().forEach((d, i) => {
          const on = i === idx;
          d.classList.toggle('active', on);
          d.setAttribute('aria-selected', on ? 'true' : 'false');
        });
      }
    }

    function scrollToIndex(idx, smooth){
      const slides = getSlides();
      const slide = slides[idx];
      if(!slide) return;
      // Scroll the track horizontally instead of using scrollIntoView on the slide,
      // to avoid moving the whole page when the carousel auto-advances.
      const x = slide.offsetLeft;
      track.scrollTo({ left: x, behavior: smooth ? 'smooth' : 'auto' });
    }

    function next(){
      const slides = getSlides();
      if(slides.length === 0) return;
      scrollToIndex((current + 1) % slides.length, true);
    }

    function start(){
      if(reducedMotion) return;
      if(autoplayTimer || hover || focus || pointerDown) return;
      autoplayTimer = setInterval(next, 3000);
    }
    function stop(){ if(autoplayTimer){ clearInterval(autoplayTimer); autoplayTimer = null; } }

    // Observe which slide is centered/visible
    const io = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if(entry.isIntersecting && entry.intersectionRatio >= 0.6){
          const slides = getSlides();
          const idx = slides.indexOf(entry.target);
          if(idx !== -1) setActive(idx);
        }
      });
    }, { root: track, threshold: [0.6] });
    getSlides().forEach(s => io.observe(s));

    // Pause/resume conditions
    track.addEventListener('mouseenter', () => { hover = true; stop(); });
    track.addEventListener('mouseleave', () => { hover = false; start(); });
    track.addEventListener('focusin', () => { focus = true; stop(); });
    track.addEventListener('focusout', () => { focus = false; start(); });
    track.addEventListener('pointerdown', () => { pointerDown = true; stop(); });
    track.addEventListener('pointerup', () => { pointerDown = false; start(); });

    // Rebuild when slides change
    const mo = new MutationObserver((mut) => {
      let changed = false;
      mut.forEach(m => { if(m.type === 'childList') changed = true; });
      if(changed){
        getSlides().forEach(s => io.observe(s));
        buildDots();
      }
    });
    mo.observe(track, { childList: true });

    setActive(0);
    start();
  }
})();
