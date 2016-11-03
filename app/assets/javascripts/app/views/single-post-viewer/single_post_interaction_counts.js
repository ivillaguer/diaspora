// @license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt AGPL-v3-or-Later

app.views.SinglePostInteractionCounts = app.views.Base.extend({
  templateName: "single-post-viewer/single-post-interaction-counts",
  tooltipSelector: ".avatar.micro",

  initialize: function() {
    this.model.interactions.on("change", this.render, this);
  },

  presenter: function() {
    var interactions = this.model.interactions;
    return {
      likes: interactions.likes.toJSON(),
      reshares: interactions.reshares.toJSON(),
      commentsCount: interactions.commentsCount(),
      likesCount: interactions.likesCount(),
      resharesCount: interactions.resharesCount()
    };
  }
});
// @license-end
