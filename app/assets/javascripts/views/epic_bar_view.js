/* eslint global-require:"off" */
/* eslint max-len:"off" */
module.exports = Backbone.View.extend({

  template: require('templates/epic_bar.ejs'),

  className: 'iteration',

  render() {
    this.$el.html(this.template({ points: this.points(), done: this.donePoints(), remaining: this.remainingPoints() }));
    return this;
  },

  points() {
    const estimates = this.model.search.pluck('estimate');

    return this.sumPoints(estimates);
  },

  estimateAction(callback) {
    const estimates = _.map(callback, e => e.get('estimate'));

    return this.sumPoints(estimates);
  },

  donePoints() {
    this.estimateAction(this.done());
  },

  remainingPoints() {
    this.estimateAction(this.remaining());
  },

  done() {
    return _.select(this.model.search.models, story => (story.get('state') === 'accepted'));
  },

  remaining() {
    return _.select(this.model.search.models, story => (story.get('state') !== 'accepted'));
  },

  sumPoints(estimates) {
    const sum = _.reduce(estimates, (total, estimate) => total + estimate);

    return sum;
  },
});
