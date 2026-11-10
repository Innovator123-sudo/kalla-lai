/* Kalla-Lai startup site — small, dependency-free interactions. */
(function () {
  "use strict";

  /* Only enable scroll-reveal hiding when JS is actually running. Without JS
     (or if this file fails to load) all content stays visible by default. */
  window.__kallaLaiBooted = true;
  document.documentElement.classList.add("js");

  /* Mobile navigation */
  var header = document.querySelector(".site-header");
  var toggle = document.querySelector(".nav__toggle");
  if (header && toggle) {
    toggle.addEventListener("click", function () {
      var open = header.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    });
    document.querySelectorAll(".nav__links a").forEach(function (link) {
      link.addEventListener("click", function () {
        header.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && header.classList.contains("is-open")) {
        header.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  /* Scroll reveal (progressive enhancement: content stays visible without JS) */
  var reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && reveals.length) {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px -40px 0px" }
    );
    reveals.forEach(function (el) {
      observer.observe(el);
    });
  } else {
    reveals.forEach(function (el) {
      el.classList.add("is-visible");
    });
  }

  /* Worker / employer tabs */
  var tabs = Array.prototype.slice.call(document.querySelectorAll(".tab"));
  if (tabs.length) {
    tabs.forEach(function (tab) {
      tab.addEventListener("click", function () {
        var target = tab.getAttribute("data-target");
        tabs.forEach(function (t) {
          t.setAttribute("aria-selected", String(t === tab));
        });
        document.querySelectorAll(".tab-panel").forEach(function (panel) {
          panel.hidden = panel.id !== target;
        });
      });
    });
  }

  /* FAQ accordion */
  document.querySelectorAll(".accordion__trigger").forEach(function (trigger) {
    trigger.addEventListener("click", function () {
      var expanded = trigger.getAttribute("aria-expanded") === "true";
      var content = document.getElementById(trigger.getAttribute("aria-controls"));
      trigger.setAttribute("aria-expanded", String(!expanded));
      if (content) content.hidden = expanded;
    });
  });

  /* Pitch deck */
  var slides = Array.prototype.slice.call(document.querySelectorAll(".slide"));
  if (slides.length) {
    var index = 0;
    var counter = document.querySelector(".deck__count");
    function render() {
      slides.forEach(function (slide, i) {
        slide.hidden = i !== index;
      });
      if (counter) counter.textContent = index + 1 + " / " + slides.length;
      var hash = "#slide-" + (index + 1);
      if (history.replaceState) history.replaceState(null, "", hash);
    }
    function go(delta) {
      index = (index + delta + slides.length) % slides.length;
      render();
      var frame = document.querySelector(".deck__frame");
      if (frame) frame.scrollIntoView({ behavior: "smooth", block: "center" });
    }
    document.querySelectorAll("[data-deck-prev]").forEach(function (b) {
      b.addEventListener("click", function () { go(-1); });
    });
    document.querySelectorAll("[data-deck-next]").forEach(function (b) {
      b.addEventListener("click", function () { go(1); });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "ArrowRight" || e.key === "PageDown") go(1);
      if (e.key === "ArrowLeft" || e.key === "PageUp") go(-1);
    });
    var fromHash = parseInt((location.hash.match(/slide-(\d+)/) || [])[1], 10);
    if (fromHash >= 1 && fromHash <= slides.length) index = fromHash - 1;
    render();
  }

  /* Current year */
  document.querySelectorAll("[data-year]").forEach(function (el) {
    el.textContent = String(new Date().getFullYear());
  });
})();
