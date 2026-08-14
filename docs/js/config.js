/* VicThree Defence — CDS PYQ Library: site config. */
window.VTPYQ_CONFIG = {
  /* LEAD CAPTURE (welcome popup -> Google Form -> linked Google Sheet).
     The three "entry.xxxx" ids and the form action URL come from the Form's
     "Get pre-filled link". Leave ids blank to keep the popup working without
     recording. */
  googleForm: {
    action: "https://docs.google.com/forms/d/e/1FAIpQLSdy4rD16a6hEHsDCr1vUyF0ra1DoV8phILZYkff1gahQDfalQ/formResponse",
    fields: {
      name:  "entry.922828093",
      phone: "entry.159932816",
      email: "entry.1662375640"
    }
  },

  /* Advanced alternative (Apps Script Web App). Ignored if googleForm is filled. */
  sheetEndpoint: ""
};
