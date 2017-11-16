package socialForce.markup;

public class Rect implements IMarkup {

	private Point p;
	private double width;
	private double height;
	
	public Rect(Point p, double width, double height) {
		this.p = p;
		this.width = width;
		this.height = height;
	}
	
	public Point getRef() {
		return this.p;
	}
	
	public double getWidth() {
		return this.width;
	}
	
	public double getHeight() {
		return this.height;
	}
	
	public Point randomPointInside() {
		double randX = this.p.getX() + Math.random() * width;
		double randY = this.p.getY() + Math.random() * height;
		
		return new Point(randX, randY);
	}

	@Override
	public double getNearestPoint(double x, double y, Point p) {
		// TODO Auto-generated method stub
		return 0;
	}
}
